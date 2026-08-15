begin;

create extension if not exists pgtap with schema extensions;

select plan(39);

select has_table('public', 'user_profiles', 'user_profiles exists');
select has_table('public', 'user_preferences', 'user_preferences exists');
select has_table('private', 'account_preference_bootstrap', 'private bootstrap marker exists');

select columns_are(
  'public',
  'user_profiles',
  array['id', 'display_name', 'status', 'created_at', 'updated_at'],
  'user_profiles has only the Stage 1 columns'
);
select columns_are(
  'public',
  'user_preferences',
  array['user_id', 'sound_enabled', 'haptic_enabled', 'created_at', 'updated_at', 'selected_coin_id'],
  'user_preferences has the account and selected coin columns'
);
select columns_are(
  'private',
  'account_preference_bootstrap',
  array['user_id', 'claimed_at'],
  'bootstrap marker contains only its key and timestamp'
);

select col_type_is('public', 'user_profiles', 'id', 'uuid', 'profile id is uuid');
select col_type_is('public', 'user_profiles', 'display_name', 'text', 'display name is text');
select col_type_is('public', 'user_profiles', 'status', 'text', 'profile status is text');
select col_type_is('public', 'user_profiles', 'created_at', 'timestamp with time zone', 'profile created_at is timestamptz');
select col_type_is('public', 'user_profiles', 'updated_at', 'timestamp with time zone', 'profile updated_at is timestamptz');
select col_type_is('public', 'user_preferences', 'user_id', 'uuid', 'preference user id is uuid');
select col_type_is('public', 'user_preferences', 'sound_enabled', 'boolean', 'sound flag is boolean');
select col_type_is('public', 'user_preferences', 'haptic_enabled', 'boolean', 'haptic flag is boolean');
select col_type_is('public', 'user_preferences', 'created_at', 'timestamp with time zone', 'preference created_at is timestamptz');
select col_type_is('public', 'user_preferences', 'updated_at', 'timestamp with time zone', 'preference updated_at is timestamptz');
select col_type_is('private', 'account_preference_bootstrap', 'user_id', 'uuid', 'bootstrap user id is uuid');
select col_type_is('private', 'account_preference_bootstrap', 'claimed_at', 'timestamp with time zone', 'bootstrap claim time is timestamptz');

select col_not_null('public', 'user_profiles', 'id', 'profile id is required');
select col_is_null('public', 'user_profiles', 'display_name', 'display name is nullable');
select col_not_null('public', 'user_profiles', 'status', 'profile status is required');
select col_not_null('public', 'user_profiles', 'created_at', 'profile created_at is required');
select col_not_null('public', 'user_profiles', 'updated_at', 'profile updated_at is required');
select col_not_null('public', 'user_preferences', 'user_id', 'preference user id is required');
select col_not_null('public', 'user_preferences', 'sound_enabled', 'sound flag is required');
select col_not_null('public', 'user_preferences', 'haptic_enabled', 'haptic flag is required');
select col_not_null('public', 'user_preferences', 'created_at', 'preference created_at is required');
select col_not_null('public', 'user_preferences', 'updated_at', 'preference updated_at is required');

select col_default_is('public', 'user_profiles', 'status', 'active', 'profile status defaults active');
select col_default_is('public', 'user_profiles', 'created_at', 'now()', 'profile created_at defaults now');
select col_default_is('public', 'user_profiles', 'updated_at', 'now()', 'profile updated_at defaults now');
select col_default_is('public', 'user_preferences', 'sound_enabled', 'true', 'sound defaults enabled');
select col_default_is('public', 'user_preferences', 'haptic_enabled', 'true', 'haptic defaults enabled');
select col_default_is('public', 'user_preferences', 'created_at', 'now()', 'preference created_at defaults now');
select col_default_is('public', 'user_preferences', 'updated_at', 'now()', 'preference updated_at defaults now');

select col_is_pk('public', 'user_profiles', 'id', 'profile id is the primary key');
select col_is_pk('public', 'user_preferences', 'user_id', 'preference user id is the primary key');
select col_is_pk('private', 'account_preference_bootstrap', 'user_id', 'bootstrap user id is the primary key');

select is(
  (
    select count(*)::integer
    from information_schema.columns
    where table_schema in ('public', 'private')
      and column_name = any(array[
        'apple_' || 'subject',
        'provider_' || 'subject',
        'selected_' || 'coin_slug'
      ])
  ),
  0,
  'provider subject and selected coin slug columns do not exist'
);

select * from finish();
rollback;
