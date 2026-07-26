# Counter POS

A responsive Flutter cashier workspace with a searchable product catalog,
cart, payment methods, session orders, reports, product management, and
backend connection diagnostics.

## Price convention before migration

Until the product table has a dedicated price column, the register reads the
first number in `description` as the price:

```text
$4.50 · Iced · 16 oz
```

This keeps the current backend contract working. Replace `productPrice` in
`lib/models/backend_test_item.dart` after your product migration is ready.

## Backend table

Create a table with these columns:

| Column | Suggested type | Notes |
| --- | --- | --- |
| `id` | integer or UUID | Primary key with a generated default |
| `title` | text | Required |
| `description` | text | Required |
| `status` | text | Values used by the UI: `pending`, `active`, `inactive` |
| `created_at` | timestamp with time zone | Default to the current timestamp |
| `image_name` | text | Optional POS-style product image name |
| `image_data` | text | Optional Base64 image data URL |

The anonymous role/key must have `SELECT`, `INSERT`, `UPDATE`, and `DELETE`
permission for this table. If row-level security is enabled, add matching
policies. The dashboard intentionally reports permission failures instead of
working around them.

## Enable product images

Run [`migrations/001_add_product_images.sql`](migrations/001_add_product_images.sql)
in your backend SQL workspace, then refresh the dashboard. The app accepts PNG,
JPEG, WebP, and GIF images up to 2 MB and proves that the image can be created,
read, replaced, and deleted with its record.

This test stores the image in PostgreSQL because the custom backend does not yet
provide object storage. For a production POS with many or large images, add an
object-storage upload API and keep only its image URL in the table.

## Enable barcodes and categories

Run
[`migrations/002_add_barcodes_and_categories.sql`](migrations/002_add_barcodes_and_categories.sql)
in your backend SQL workspace. This adds optional product barcodes and the
category table used by the Products and Register screens.

## Configure

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) and
   confirm `flutter doctor` succeeds for the platforms you want to run.
2. Copy `.env.example` to `.env`.
3. Open `.env` and insert your real backend base URL and anonymous key:

   ```env
   BACKEND_URL=https://your-backend-url.com
   ANON_KEY=your-anon-key
   ```

Never commit `.env`; it is already ignored. `flutter_dotenv` bundles `.env`
into the client application, so an anonymous/public client key is appropriate,
but an admin or service-role secret is not.

Use HTTPS outside local development. Web builds also require the backend to
allow the dashboard origin through its CORS configuration.

## Run

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Replace `chrome` with a device listed by `flutter devices`, such as `macos`,
`windows`, an Android emulator, or an iOS simulator.

## API contract

All operations use:

```text
<BACKEND_URL>/rest/v1/backend_test_items
```

Requests send `Content-Type: application/json`, `apikey: ANON_KEY`, and
`Authorization: Bearer ANON_KEY`. Requests time out after 12 seconds. The UI
shows exact HTTP status codes and backend error messages; debug logs mask the
API key.
