alter table public.user_preferences
add column selected_coin_id uuid null
references public.coins(id)
on delete set null;

grant update (selected_coin_id)
on table public.user_preferences
to authenticated;
