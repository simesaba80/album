# Cookie Session Authentication Plan

## Goal

Rails API で Cookie ベースの認証を使い、Next.js フロントエンドから `credentials: "include"` でログイン状態を維持する。

この方式は、ログイン画面、ログアウト、ユーザーごとの認証、将来的な権限管理を必要とする場合に向いている。

## Current State

- `users` テーブルと `sessions` テーブルはすでにある。
- `User` は `has_secure_password` を使っている。
- `Session` は `User` に紐づく。
- `app/controllers/concerns/authentication.rb` は Cookie の `session_id` から `Session` を復元する設計になっている。
- ただし `ApplicationController` では `Authentication` が include されていない。
- `ApplicationController` は `ActionController::API` 継承で、Rails API mode のため Cookie/session 系middlewareが通常のRailsアプリほど有効ではない。
- `SessionsController` と `PasswordsController` は redirect 前提で、JSON APIとしては未整備。
- CORS は `origins "*"` で、認証Cookieを含むリクエストには不向き。

## Recommended Design

既存の `sessions` テーブルを活かす。

Rails の `session[:user_id]` にユーザーIDを保存する方式ではなく、DB上の `sessions` レコードIDを `HttpOnly` Cookie に入れる方式を採用する。

理由:

- サーバー側でセッションを失効できる。
- 端末ごとのセッション管理に拡張しやすい。
- 既存の `Session` model と `Authentication` concern を活かせる。
- Cookie内にユーザー情報を直接持たない。

Cookieには `session_id` の署名付き値だけを保存する。

## Backend Implementation

1. Rails API mode で Cookie を扱えるようにする。

   `cookies.signed[:session_id]` だけ使うなら、少なくとも Cookie middleware と controller module を有効化する。

   ```ruby
   # config/application.rb
   config.middleware.use ActionDispatch::Cookies
   ```

   ```ruby
   # app/controllers/application_controller.rb
   class ApplicationController < ActionController::API
     include ActionController::Cookies
     include Authentication
   end
   ```

2. `Authentication` concern を API 向けレスポンスに変更する。

   現在は未認証時に `redirect_to new_session_path` する設計なので、JSON APIでは `401 Unauthorized` を返す。

   ```ruby
   def request_authentication
     render json: { error: "Unauthorized" }, status: :unauthorized
   end
   ```

   `session[:return_to_after_authenticating]` はRails画面遷移用なので不要。

3. Cookie属性をAPI用途に合わせる。

   開発環境で Next.js と Rails が `localhost` の別ポートなら `same_site: :lax` で成立する可能性が高い。

   本番で frontend/backend が別ドメインになる場合は `same_site: :none` と `secure: true` が必要になる。

   ```ruby
   cookies.signed.permanent[:session_id] = {
     value: session.id,
     httponly: true,
     same_site: Rails.env.production? ? :none : :lax,
     secure: Rails.env.production?
   }
   ```

4. `SessionsController` をJSON API化する。

   - `POST /session`
     - 成功: セッション作成、Cookie設定、`200 OK`
     - 失敗: `401 Unauthorized`
   - `DELETE /session`
     - セッション削除、Cookie削除、`204 No Content`
   - `GET /session`
     - ログイン状態確認用。ログイン済みならユーザー情報を返す。

   例:

   ```ruby
   def create
     user = User.authenticate_by(params.permit(:email_address, :password))

     if user
       start_new_session_for(user)
       render json: { user: user_response(user) }, status: :ok
     else
       render json: { error: "Unauthorized" }, status: :unauthorized
     end
   end
   ```

5. `PasswordsController` もJSON API化する。

   既存のパスワードリセット画面をNext.js側に残すなら、RailsはJSONだけ返す。

   - `POST /passwords`: 常に `202 Accepted` などを返す。ユーザー有無は漏らさない。
   - `PUT /passwords/:token`: 成功時 `204 No Content`、失敗時 `422 Unprocessable Entity` または `404 Not Found`

6. routes をAPI向けに整理する。

   ```ruby
   resource :session, only: %i[show create destroy]
   resources :passwords, param: :token, only: %i[create update]
   resources :albums
   ```

   `new`、`edit` はNext.js側の画面なのでRails routesから外す。

7. CORS を credentials 対応に変更する。

   `origins "*"` は使わず、Next.js の origin を明示する。

   ```ruby
   Rails.application.config.middleware.insert_before 0, Rack::Cors do
     allow do
       origins ENV.fetch("FRONTEND_ORIGIN", "http://localhost:3001")
       resource "*",
         headers: :any,
         methods: %i[get post patch put delete options head],
         credentials: true
     end
   end
   ```

## Frontend Integration

`fetch` には `credentials: "include"` を付ける。

対象:

- `fetchAlbums`
- `fetchAlbum`
- `createAlbum`
- `updateAlbum`
- `deleteAlbum`
- `login`
- `requestPasswordReset`
- `resetPassword`
- `logout`
- `fetchCurrentSession`

例:

```ts
const res = await fetch(`${API_URL}/albums`, {
  cache: "no-store",
  credentials: "include",
});
```

ログイン状態確認用のAPIを追加する。

```ts
export async function fetchCurrentSession(): Promise<CurrentSession | null> {
  const res = await fetch(`${API_URL}/session`, {
    cache: "no-store",
    credentials: "include",
  });

  if (res.status === 401) return null;
  if (!res.ok) throw new Error("Failed to fetch session");
  return res.json();
}
```

## Route And UI Changes

- 未ログイン時は `/login` に誘導する。
- ログイン済みなら `/login` から `/` に戻す。
- header の `Login` はログイン状態に応じて `Logout` またはユーザー表示に変える。
- album作成・編集・削除は未ログイン時に実行できない。

Next.js App Router の Server Components からRails APIを直接叩く場合、ブラウザのCookieをRails APIへ明示的に渡す設計が必要になる。実装を単純にするなら、Next.js Route Handler を中継にして、Cookie転送をサーバー側で統一する。

## CSRF Considerations

Cookie認証ではCSRFを考慮する。

選択肢:

1. frontend/backend を同一サイト扱いにし、`SameSite=Lax` を基本にする。
2. 破壊的操作にCSRFトークンを要求する。
3. API proxy をNext.jsに置き、ブラウザからRailsへ直接Cookie付きリクエストを送らない構成にする。

このプロジェクトでは、まず `SameSite=Lax` と明示CORSで進め、別ドメイン本番運用が必要になった時点でCSRFトークンまたはNext.js proxyを追加するのが現実的。

## Tests

Rails:

- 未ログインで `GET /albums` が `401` を返す。
- ログイン成功で `session_id` Cookie が設定される。
- ログイン失敗で `401`、Cookieなし。
- Cookie付きで `GET /albums` が成功する。
- ログアウトでDB session と Cookie が削除される。
- パスワードリセットAPIがJSONレスポンスを返す。

Next.js:

- `login` が `credentials: "include"` 付きで送信される。
- 未ログイン時に保護ページから `/login` へ誘導される。
- ログアウト後に保護ページへ戻れない。

## Security Notes

- Cookie は `HttpOnly` にする。
- 本番では `secure: true` を使う。
- CORSの `origins "*"` と `credentials: true` を組み合わせない。
- `session_id` の実体はDB上の `sessions` レコードにし、ユーザー情報はCookieへ入れない。
- パスワードリセットではユーザー有無をレスポンスから推測できないようにする。
- セッション削除時はDBとCookieの両方を消す。

## Pros

- 既存の `User`、`Session`、`has_secure_password` を活かせる。
- ログイン、ログアウト、パスワードリセットと相性がよい。
- 将来的なユーザー別権限管理に拡張しやすい。
- セッションの個別失効ができる。

## Cons

- Basic認証より実装箇所が多い。
- CORS、Cookie属性、CSRFの設計が必要。
- frontend/backend のドメイン構成に影響される。
- Server Components からのデータ取得ではCookie転送設計が必要。

## Implementation Order

1. Railsで Cookie middleware と `ActionController::Cookies` を有効化する。
2. `Authentication` concern をJSON API向けに変更する。
3. `ApplicationController` に `Authentication` を include する。
4. `SessionsController` をJSON API化する。
5. `PasswordsController` をJSON API化する。
6. routes から `new` / `edit` を外し、API route に整理する。
7. CORSを credentials 対応に変更する。
8. Rails controller test を追加・修正する。
9. Next.js の API helper に `credentials: "include"` を追加する。
10. frontend のログイン状態管理とログアウトUIを追加する。
11. backend/frontend の動作確認を行う。
