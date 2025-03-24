-- Labels table
create table public.labels (
  id uuid not null default extensions.uuid_generate_v4(),
  user_id uuid not null,
  name text not null,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  constraint labels_pkey primary key (id),
  constraint labels_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade
);

-- Contacts table
create table public.contacts (
  id uuid not null default extensions.uuid_generate_v4(),
  user_id uuid not null,
  name text null,
  phone_number text null,
  email text null,
  system_contact_id text null, -- Reference to the iOS system contact ID
  text_description text null,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  constraint contacts_pkey primary key (id),
  constraint contacts_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade
);

-- Contact labels (many-to-many relationship)
create table public.contact_labels (
  id uuid not null default extensions.uuid_generate_v4(),
  contact_id uuid not null,
  label_id uuid not null,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  constraint contact_labels_pkey primary key (id),
  constraint contact_labels_contact_id_fkey foreign key (contact_id) references public.contacts (id) on delete cascade,
  constraint contact_labels_label_id_fkey foreign key (label_id) references public.labels (id) on delete cascade,
  constraint contact_labels_contact_id_label_id_key unique (contact_id, label_id)
);

-- User preferences table
create table public.user_preferences (
  id uuid not null default extensions.uuid_generate_v4(),
  user_id uuid not null,
  has_completed_onboarding boolean null default false,
  has_synced_contacts boolean null default false,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  constraint user_preferences_pkey primary key (id),
  constraint user_preferences_user_id_key unique (user_id),
  constraint user_preferences_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade
);

-- Subscriptions table for in-app purchases (will use StoreKit later)
create table public.app_subscriptions (
  id uuid not null default extensions.uuid_generate_v4(),
  user_id uuid not null,
  product_id text null,
  status text null, -- active, expired, etc.
  expires_at timestamp with time zone null,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  constraint app_subscriptions_pkey primary key (id),
  constraint app_subscriptions_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade
);

-- Enable RLS on all tables
alter table public.labels enable row level security;
alter table public.contacts enable row level security;
alter table public.contact_labels enable row level security;
alter table public.user_preferences enable row level security;
alter table public.app_subscriptions enable row level security;

-- Labels policies
create policy "Users can read their own labels" on public.labels
  for select using (auth.uid() = user_id);

create policy "Users can update their own labels" on public.labels
  for update using (auth.uid() = user_id);

create policy "Users can insert their own labels" on public.labels
  for insert with check (auth.uid() = user_id);

create policy "Users can delete their own labels" on public.labels
  for delete using (auth.uid() = user_id);

-- Contacts policies
create policy "Users can read their own contacts" on public.contacts
  for select using (auth.uid() = user_id);

create policy "Users can update their own contacts" on public.contacts
  for update using (auth.uid() = user_id);

create policy "Users can insert their own contacts" on public.contacts
  for insert with check (auth.uid() = user_id);

create policy "Users can delete their own contacts" on public.contacts
  for delete using (auth.uid() = user_id);

-- Contact labels policies
create policy "Users can read their own contact labels" on public.contact_labels
  for select using (
    auth.uid() = (
      select user_id from public.contacts where id = contact_id
    )
  );

create policy "Users can insert their own contact labels" on public.contact_labels
  for insert with check (
    auth.uid() = (
      select user_id from public.contacts where id = contact_id
    )
  );

create policy "Users can delete their own contact labels" on public.contact_labels
  for delete using (
    auth.uid() = (
      select user_id from public.contacts where id = contact_id
    )
  );

-- User preferences policies
create policy "Users can read their own preferences" on public.user_preferences
  for select using (auth.uid() = user_id);

create policy "Users can update their own preferences" on public.user_preferences
  for update using (auth.uid() = user_id);

create policy "Users can insert their own preferences" on public.user_preferences
  for insert with check (auth.uid() = user_id);

-- App subscriptions policies
create policy "Users can read their own subscriptions" on public.app_subscriptions
  for select using (auth.uid() = user_id);

create policy "Users can update their own subscriptions" on public.app_subscriptions
  for update using (auth.uid() = user_id);

create policy "Users can insert their own subscriptions" on public.app_subscriptions
  for insert with check (auth.uid() = user_id);
