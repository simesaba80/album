# Basic Authentication Plan

## Goal

Rails API を HTTP Basic 認証で保護する。Rails の Cookie/session は使わず、各リクエストの `Authorization` ヘッダーで認証する。

この方式は、単一または少数の共有認証情報でアプリ全体を保護したい場合に向いている。ユーザーごとのログイン、ログアウト、パスワードリセット、権限管理が必要な場合は Cookie セッション認証またはトークン認証を選ぶ。

## Current State

- `ApplicationController` は `ActionController::API` を継承している。
- 既存の `Authentication` concern、`SessionsController`、`PasswordsController` は Rails の通常アプリ寄りの Cookie/session 認証を前提としている。
- 現在 `ApplicationController` では `Authentication` concern が include されておらず、API保護には使われていない。
- `albums` API は未認証で利用できる。

## Design

Rails 標準の HTTP Basic 認証を使う。追加 gem は不要。

認証情報は環境変数または Rails credentials に保存する。まずは環境変数を推奨する。

- `BASIC_AUTH_USERNAME`
- `BASIC_AUTH_PASSWORD`

認証対象は `albums` API 全体とする。ヘルスチェックの `/up` は認証対象外にする。

## Backend Implementation

1. Basic 認証用 concern を追加する。

   例: `app/controllers/concerns/basic_authentication.rb`

   ```ruby
   module BasicAuthentication
     extend ActiveSupport::Concern

     included do
       before_action :authenticate_with_basic_auth
     end

     class_methods do
       def allow_unauthenticated_access(**options)
         skip_before_action :authenticate_with_basic_auth, **options
       end
     end

     private
       def authenticate_with_basic_auth
         authenticate_or_request_with_http_basic do |username, password|
           secure_compare(username, ENV.fetch("BASIC_AUTH_USERNAME")) &&
             secure_compare(password, ENV.fetch("BASIC_AUTH_PASSWORD"))
         end
       end

       def secure_compare(value, expected)
         ActiveSupport::SecurityUtils.secure_compare(
           Digest::SHA256.hexdigest(value.to_s),
           Digest::SHA256.hexdigest(expected.to_s)
         )
       end
   end
   ```

2. `ApplicationController` に include する。

   ```ruby
   class ApplicationController < ActionController::API
     include BasicAuthentication
   end
   ```

3. `/up` は Rails health controller なので追加対応不要。独自の公開APIを作る場合は `allow_unauthenticated_access` を使う。

4. 既存の `Authentication` concern、`SessionsController`、`PasswordsController` は今回の方式では使わない。混乱を避けるため、ルーティングから外し、後続タスクで削除または別ブランチに退避する。

## Frontend Integration

ブラウザに Basic 認証のID/パスワードを置かない。

Next.js 側に Route Handler または API proxy を作り、ブラウザは Next.js にだけアクセスする。Next.js サーバーが Rails API に `Authorization: Basic ...` を付けて転送する。

例:

- Browser -> `GET /api/albums`
- Next.js server -> `GET {RAILS_API_URL}/albums` with `Authorization: Basic ...`

Next.js 側の環境変数:

- `RAILS_API_URL`
- `RAILS_BASIC_AUTH_USERNAME`
- `RAILS_BASIC_AUTH_PASSWORD`

`NEXT_PUBLIC_` prefix は付けない。ブラウザに公開されるため。

## Route And UI Changes

- `/login`
- `/passwords/new`
- `/passwords/[token]/edit`

これらは Basic 認証では不要。画面もBasic認証で守る場合は、Next.js middleware、デプロイ先、またはリバースプロキシでフロント全体にも Basic 認証をかける。

Rails API だけをBasic認証にしても、フロント画面が公開されているとUIは誰でも見られる。実運用ではフロント側も同じ認証境界に入れる。

## Tests

Rails:

- 認証ヘッダーなしで `GET /albums` が `401` を返す。
- 不正な認証ヘッダーで `401` を返す。
- 正しい認証ヘッダーで `200` を返す。
- `POST /albums`、`PATCH /albums/:id`、`DELETE /albums/:id` も認証なしでは `401` を返す。

Next.js:

- proxy が `Authorization` ヘッダーを付けてRails APIへ転送する。
- Rails APIの `401` を適切にUIへ伝える。

## Security Notes

- Basic 認証は必ず HTTPS 前提で使う。
- 認証情報はDBではなく環境変数または credentials で管理する。
- ログに `Authorization` ヘッダーを出さない。
- 複数ユーザー、個別失効、監査ログが必要になったら Basic 認証から移行する。

## Pros

- 実装が最も単純。
- 追加ライブラリ不要。
- API全体を短期間で保護できる。
- DBセッションやCSRF設計が不要。

## Cons

- ユーザー単位の認証・認可には向かない。
- ログアウトや端末別セッション管理がない。
- パスワード変更時は全利用者に影響する。
- ブラウザ直叩き構成では認証情報の秘匿が難しいため、Next.js proxy が必要。

## Implementation Order

1. `BasicAuthentication` concern を追加する。
2. `ApplicationController` に include する。
3. Rails controller test を追加・修正する。
4. Next.js proxy を追加する。
5. frontend の `src/lib/api.ts` を proxy 経由に変更する。
6. 不要なログイン・パスワードリセット導線を撤去する。
7. backend/frontend の動作確認を行う。
