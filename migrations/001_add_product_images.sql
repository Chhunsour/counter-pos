alter table api.backend_test_items
  add column if not exists image_name text,
  add column if not exists image_data text;

comment on column api.backend_test_items.image_name is
  'User-visible POS product image name.';
comment on column api.backend_test_items.image_data is
  'Small image stored as a Base64 data URL for backend testing.';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'backend_test_items_image_check'
      and conrelid = 'api.backend_test_items'::regclass
  ) then
    alter table api.backend_test_items
      add constraint backend_test_items_image_check check (
        image_data is null
        or (
          image_name is not null
          and length(btrim(image_name)) between 1 and 160
          and length(image_data) <= 2800000
          and image_data ~ '^data:image/(png|jpeg|webp|gif);base64,'
        )
      );
  end if;
end
$$;
