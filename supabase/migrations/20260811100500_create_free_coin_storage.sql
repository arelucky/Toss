insert into storage.buckets (id, name, public, file_size_limit)
values
  ('coin-previews', 'coin-previews', true, 2097152),
  ('coin-models-free', 'coin-models-free', true, 52428800),
  ('coin-staging', 'coin-staging', false, 52428800);

create policy "free coin assets are publicly readable"
on storage.objects
for select
to anon, authenticated
using (
  (
    bucket_id = 'coin-previews'
    and name ~ '^coins/[^/]+/v[1-9][0-9]*/preview[.]webp$'
  )
  or (
    bucket_id = 'coin-models-free'
    and name ~ '^coins/[^/]+/v[1-9][0-9]*/model[.]usdz$'
  )
);
