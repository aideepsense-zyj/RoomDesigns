# Supabase 数据库设置指南

## 问题说明

当在 Supabase 中执行 SQL 时遇到 `ERROR: 42501: must be owner of table users` 错误，这是因为：

1. `auth.users` 表是 Supabase 的系统表，普通用户没有权限直接修改
2. 不能在 `auth.users` 表上创建触发器或修改其结构
3. 需要使用安全的方式来处理用户相关的操作

## 解决方案

### 步骤 1：使用安全的数据库设置脚本

执行以下 SQL 文件（按顺序）：

1. **20250131000001_safe_database_setup.sql** - 创建所有必要的表和策略
2. **20250131000002_auto_create_customer_safe.sql** - 安全的用户客户记录创建

### 步骤 2：在 Supabase 控制台中执行

1. 登录 [Supabase 控制台](https://supabase.com/dashboard)
2. 选择你的项目
3. 进入 **SQL Editor**
4. 复制并执行 `20250131000001_safe_database_setup.sql` 的内容
5. 复制并执行 `20250131000002_auto_create_customer_safe.sql` 的内容

### 步骤 3：验证设置

执行以下查询来验证表是否创建成功：

```sql
-- 检查表是否存在
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('customers', 'credits_history', 'subscriptions', 'name_generation_logs', 'saved_names', 'popular_names');

-- 检查 RLS 是否启用
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND rowsecurity = true;

-- 检查策略是否创建
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public';
```

## 主要改进

### 1. 避免直接操作 auth.users 表
- 不在 `auth.users` 表上创建触发器
- 使用应用层函数来确保客户记录存在

### 2. 安全的用户初始化
- 创建 `ensure_customer_exists()` 函数
- 创建 `initialize_user_account()` RPC 函数供前端调用

### 3. 完整的 RLS 策略
- 为所有表启用行级安全
- 确保用户只能访问自己的数据

## 应用层集成

在你的应用中，可以在用户登录后调用：

```javascript
// 在用户登录后调用此函数
const { data, error } = await supabase.rpc('initialize_user_account');

if (error) {
  console.error('初始化用户账户失败:', error);
} else {
  console.log('用户账户初始化成功:', data);
}
```

## 注意事项

1. **不要直接修改 auth.users 表** - 这是 Supabase 的系统表
2. **使用 RPC 函数** - 通过 `supabase.rpc()` 调用自定义函数
3. **检查权限** - 确保所有操作都通过 RLS 策略验证
4. **测试功能** - 在生产环境使用前充分测试所有功能

## 故障排除

如果仍然遇到权限问题：

1. 确保你是项目的所有者或管理员
2. 检查 Supabase 项目的角色权限设置
3. 使用 `service_role` 密钥执行管理操作（仅在服务器端）
4. 联系 Supabase 支持获取帮助

## 下一步

数据库设置完成后，你可以：

1. 测试用户注册和登录功能
2. 验证客户记录自动创建
3. 测试积分系统
4. 配置其他业务逻辑