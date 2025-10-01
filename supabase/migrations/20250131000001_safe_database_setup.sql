-- 安全的数据库设置脚本
-- 避免直接操作 auth.users 表

-- 1. 创建 handle_updated_at 函数（如果不存在）
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. 创建 customers 表（如果不存在）
CREATE TABLE IF NOT EXISTS public.customers (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete cascade not null,
    creem_customer_id text not null unique,
    email text not null,
    name text,
    country text,
    credits integer default 3 not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    metadata jsonb default '{}'::jsonb,
    constraint customers_email_match check (email = lower(email)),
    constraint credits_non_negative check (credits >= 0)
);

-- 3. 创建 credits_history 表（如果不存在）
CREATE TABLE IF NOT EXISTS public.credits_history (
    id uuid primary key default uuid_generate_v4(),
    customer_id uuid references public.customers(id) on delete cascade not null,
    amount integer not null,
    type text not null check (type in ('add', 'subtract')),
    description text,
    creem_order_id text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    metadata jsonb default '{}'::jsonb
);

-- 4. 创建 subscriptions 表（如果不存在）
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id uuid primary key default uuid_generate_v4(),
    customer_id uuid references public.customers(id) on delete cascade not null,
    creem_subscription_id text not null unique,
    creem_product_id text not null,
    status text not null check (status in ('incomplete', 'expired', 'active', 'past_due', 'canceled', 'unpaid', 'paused', 'trialing')),
    current_period_start timestamp with time zone not null,
    current_period_end timestamp with time zone not null,
    canceled_at timestamp with time zone,
    trial_end timestamp with time zone,
    metadata jsonb default '{}'::jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. 创建 name_generation_logs 表（如果不存在）
CREATE TABLE IF NOT EXISTS public.name_generation_logs (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete cascade not null,
    gender text not null check (gender in ('male', 'female', 'neutral')),
    surname text not null,
    generation_count integer not null default 1,
    generated_names jsonb not null default '[]'::jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    metadata jsonb default '{}'::jsonb
);

-- 6. 创建 saved_names 表（如果不存在）
CREATE TABLE IF NOT EXISTS public.saved_names (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete cascade not null,
    chinese_name text not null,
    pinyin text not null,
    meaning text,
    gender text check (gender in ('male', 'female', 'neutral')),
    surname text not null,
    is_favorite boolean default false,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    metadata jsonb default '{}'::jsonb
);

-- 7. 创建 popular_names 表（如果不存在）
CREATE TABLE IF NOT EXISTS public.popular_names (
    id uuid primary key default uuid_generate_v4(),
    chinese_name text not null,
    pinyin text not null,
    meaning text,
    gender text not null check (gender in ('male', 'female', 'neutral')),
    surname text not null,
    popularity_score integer default 0,
    view_count integer default 0,
    save_count integer default 0,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(chinese_name, surname, gender)
);

-- 8. 创建索引（如果不存在）
CREATE INDEX IF NOT EXISTS customers_user_id_idx ON public.customers(user_id);
CREATE INDEX IF NOT EXISTS customers_creem_customer_id_idx ON public.customers(creem_customer_id);
CREATE INDEX IF NOT EXISTS credits_history_customer_id_idx ON public.credits_history(customer_id);
CREATE INDEX IF NOT EXISTS subscriptions_customer_id_idx ON public.subscriptions(customer_id);
CREATE INDEX IF NOT EXISTS name_generation_logs_user_id_idx ON public.name_generation_logs(user_id);
CREATE INDEX IF NOT EXISTS saved_names_user_id_idx ON public.saved_names(user_id);
CREATE INDEX IF NOT EXISTS popular_names_gender_idx ON public.popular_names(gender);
CREATE INDEX IF NOT EXISTS popular_names_surname_idx ON public.popular_names(surname);
CREATE INDEX IF NOT EXISTS popular_names_popularity_idx ON public.popular_names(popularity_score DESC);

-- 9. 创建 updated_at 触发器
DROP TRIGGER IF EXISTS customers_updated_at ON public.customers;
CREATE TRIGGER customers_updated_at
    BEFORE UPDATE ON public.customers
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS subscriptions_updated_at ON public.subscriptions;
CREATE TRIGGER subscriptions_updated_at
    BEFORE UPDATE ON public.subscriptions
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS saved_names_updated_at ON public.saved_names;
CREATE TRIGGER saved_names_updated_at
    BEFORE UPDATE ON public.saved_names
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS popular_names_updated_at ON public.popular_names;
CREATE TRIGGER popular_names_updated_at
    BEFORE UPDATE ON public.popular_names
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 10. 启用 RLS
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credits_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.name_generation_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_names ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.popular_names ENABLE ROW LEVEL SECURITY;

-- 11. 创建 RLS 策略
-- customers 表策略
DROP POLICY IF EXISTS "Users can view their own customer data" ON public.customers;
CREATE POLICY "Users can view their own customer data"
    ON public.customers FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own customer data" ON public.customers;
CREATE POLICY "Users can update their own customer data"
    ON public.customers FOR UPDATE
    USING (auth.uid() = user_id);

-- credits_history 表策略
DROP POLICY IF EXISTS "Users can view their own credits history" ON public.credits_history;
CREATE POLICY "Users can view their own credits history"
    ON public.credits_history FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM public.customers
        WHERE customers.id = credits_history.customer_id
        AND customers.user_id = auth.uid()
    ));

-- subscriptions 表策略
DROP POLICY IF EXISTS "Users can view their own subscriptions" ON public.subscriptions;
CREATE POLICY "Users can view their own subscriptions"
    ON public.subscriptions FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM public.customers
        WHERE customers.id = subscriptions.customer_id
        AND customers.user_id = auth.uid()
    ));

-- name_generation_logs 表策略
DROP POLICY IF EXISTS "Users can view their own name generation logs" ON public.name_generation_logs;
CREATE POLICY "Users can view their own name generation logs"
    ON public.name_generation_logs FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own name generation logs" ON public.name_generation_logs;
CREATE POLICY "Users can insert their own name generation logs"
    ON public.name_generation_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- saved_names 表策略
DROP POLICY IF EXISTS "Users can view their own saved names" ON public.saved_names;
CREATE POLICY "Users can view their own saved names"
    ON public.saved_names FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own saved names" ON public.saved_names;
CREATE POLICY "Users can insert their own saved names"
    ON public.saved_names FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own saved names" ON public.saved_names;
CREATE POLICY "Users can update their own saved names"
    ON public.saved_names FOR UPDATE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own saved names" ON public.saved_names;
CREATE POLICY "Users can delete their own saved names"
    ON public.saved_names FOR DELETE
    USING (auth.uid() = user_id);

-- popular_names 表策略（所有人都可以查看）
DROP POLICY IF EXISTS "Anyone can view popular names" ON public.popular_names;
CREATE POLICY "Anyone can view popular names"
    ON public.popular_names FOR SELECT
    USING (true);

-- 12. 授予权限给 service_role
GRANT ALL ON public.customers TO service_role;
GRANT ALL ON public.credits_history TO service_role;
GRANT ALL ON public.subscriptions TO service_role;
GRANT ALL ON public.name_generation_logs TO service_role;
GRANT ALL ON public.saved_names TO service_role;
GRANT ALL ON public.popular_names TO service_role;

-- 13. 插入一些示例热门名字数据
INSERT INTO public.popular_names (chinese_name, pinyin, meaning, gender, surname, popularity_score, view_count, save_count) VALUES
('浩然', 'hào rán', '正大刚直，心胸开阔', 'male', '李', 95, 1250, 89),
('雨萱', 'yǔ xuān', '雨中的萱草，清新自然', 'female', '王', 92, 1180, 76),
('子轩', 'zǐ xuān', '有学问的人，气宇轩昂', 'male', '张', 90, 1100, 82),
('梓涵', 'zǐ hán', '梓树般茁壮，内涵丰富', 'female', '李', 88, 1050, 71),
('思远', 'sī yuǎn', '思考深远，志向远大', 'male', '陈', 87, 980, 65)
ON CONFLICT (chinese_name, surname, gender) DO NOTHING;

-- 14. 创建更新热门名字统计的函数
CREATE OR REPLACE FUNCTION public.update_popular_name_stats(
    p_chinese_name text,
    p_surname text,
    p_gender text,
    p_action text -- 'view' or 'save'
)
RETURNS void AS $$
BEGIN
    IF p_action = 'view' THEN
        UPDATE public.popular_names 
        SET view_count = view_count + 1,
            popularity_score = LEAST(100, popularity_score + 1)
        WHERE chinese_name = p_chinese_name 
        AND surname = p_surname 
        AND gender = p_gender;
    ELSIF p_action = 'save' THEN
        UPDATE public.popular_names 
        SET save_count = save_count + 1,
            popularity_score = LEAST(100, popularity_score + 2)
        WHERE chinese_name = p_chinese_name 
        AND surname = p_surname 
        AND gender = p_gender;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 授予执行权限
GRANT EXECUTE ON FUNCTION public.update_popular_name_stats TO service_role;
GRANT EXECUTE ON FUNCTION public.update_popular_name_stats TO authenticated;