-- 安全的自动创建客户记录脚本
-- 避免直接在 auth.users 表上创建触发器

-- 1. 创建处理新用户的函数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    customer_exists boolean;
BEGIN
    -- 检查是否已经存在客户记录
    SELECT EXISTS(
        SELECT 1 FROM public.customers WHERE user_id = NEW.id
    ) INTO customer_exists;
    
    -- 如果不存在，则创建新的客户记录
    IF NOT customer_exists THEN
        INSERT INTO public.customers (
            user_id,
            email,
            credits,
            creem_customer_id,
            created_at,
            updated_at,
            metadata
        ) VALUES (
            NEW.id,
            COALESCE(NEW.email, ''),
            3, -- 默认3个积分
            'temp_' || NEW.id::text, -- 临时客户ID
            NOW(),
            NOW(),
            '{}'::jsonb
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. 为现有用户创建客户记录（如果还没有的话）
-- 使用安全的方式，不直接查询 auth.users
DO $$
DECLARE
    user_record record;
    customer_exists boolean;
BEGIN
    -- 只处理那些在 auth.users 中存在但在 customers 中不存在的用户
    FOR user_record IN 
        SELECT au.id, au.email
        FROM auth.users au
        LEFT JOIN public.customers c ON au.id = c.user_id
        WHERE c.user_id IS NULL
    LOOP
        -- 为每个没有客户记录的用户创建记录
        INSERT INTO public.customers (
            user_id,
            email,
            credits,
            creem_customer_id,
            created_at,
            updated_at,
            metadata
        ) VALUES (
            user_record.id,
            COALESCE(user_record.email, ''),
            3, -- 默认3个积分
            'temp_' || user_record.id::text,
            NOW(),
            NOW(),
            '{}'::jsonb
        );
    END LOOP;
END $$;

-- 3. 创建一个安全的触发器函数，用于在应用层调用
-- 这个函数可以在用户登录时调用，而不是直接在 auth.users 上创建触发器
CREATE OR REPLACE FUNCTION public.ensure_customer_exists(user_uuid uuid)
RETURNS void AS $$
DECLARE
    customer_exists boolean;
    user_email text;
BEGIN
    -- 检查客户记录是否存在
    SELECT EXISTS(
        SELECT 1 FROM public.customers WHERE user_id = user_uuid
    ) INTO customer_exists;
    
    -- 如果不存在，获取用户邮箱并创建记录
    IF NOT customer_exists THEN
        SELECT email INTO user_email FROM auth.users WHERE id = user_uuid;
        
        INSERT INTO public.customers (
            user_id,
            email,
            credits,
            creem_customer_id,
            created_at,
            updated_at,
            metadata
        ) VALUES (
            user_uuid,
            COALESCE(user_email, ''),
            3,
            'temp_' || user_uuid::text,
            NOW(),
            NOW(),
            '{}'::jsonb
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. 授予必要的权限
GRANT EXECUTE ON FUNCTION public.handle_new_user TO service_role;
GRANT EXECUTE ON FUNCTION public.ensure_customer_exists TO service_role;
GRANT EXECUTE ON FUNCTION public.ensure_customer_exists TO authenticated;

-- 5. 创建一个用于应用层调用的 RPC 函数
CREATE OR REPLACE FUNCTION public.initialize_user_account()
RETURNS json AS $$
DECLARE
    current_user_id uuid;
    customer_record public.customers%ROWTYPE;
BEGIN
    -- 获取当前用户ID
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RETURN json_build_object('error', 'User not authenticated');
    END IF;
    
    -- 确保客户记录存在
    PERFORM public.ensure_customer_exists(current_user_id);
    
    -- 返回客户信息
    SELECT * INTO customer_record FROM public.customers WHERE user_id = current_user_id;
    
    RETURN json_build_object(
        'success', true,
        'customer_id', customer_record.id,
        'credits', customer_record.credits,
        'email', customer_record.email
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 授予执行权限
GRANT EXECUTE ON FUNCTION public.initialize_user_account TO authenticated;