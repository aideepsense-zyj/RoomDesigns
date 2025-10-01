import { signUpAction } from "@/app/actions";
import { FormMessage, Message } from "@/components/form-message";
import { SubmitButton } from "@/components/submit-button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import Link from "next/link";
import { createClient } from "@/utils/supabase/server";
import { encodedRedirect } from "@/utils/utils";
import { redirect } from "next/navigation";

export default async function SignUp(props: {
  searchParams: Promise<Message>;
}) {
  const searchParams = await props.searchParams;

  const signUpWithGoogle = async () => {
    "use server";
    const supabase = await createClient();

    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000'}/auth/callback`,
        queryParams: {
          access_type: "offline",
          prompt: "consent",
        },
      },
    });

    if (error) {
      return encodedRedirect("error", "/sign-up", error.message);
    }

    if (data.url) {
      return redirect(data.url);
    }
  };

  return (
    <>
      <div className="flex flex-col space-y-2 text-center">
        <h1 className="text-2xl font-semibold tracking-tight">Create your account</h1>
        <p className="text-sm text-muted-foreground">
          Sign up to access global authentication and payment solutions
        </p>
      </div>
      <div className="grid gap-6">
        <form className="grid gap-4">
          <div className="grid gap-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              name="email"
              placeholder="name@example.com"
              type="email"
              autoCapitalize="none"
              autoComplete="email"
              autoCorrect="off"
              required
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="password">Password</Label>
            <Input
              id="password"
              name="password"
              type="password"
              placeholder="••••••••"
              autoComplete="current-password"
              required
            />
          </div>
          {/* Only show submit button if not in success state */}
          {!(await searchParams).success && (
            <SubmitButton
              className="w-full"
              pendingText="Creating account..."
              formAction={signUpAction}
            >
              Create account
            </SubmitButton>
          )}
          <FormMessage message={searchParams} />
          
          {/* Enhanced success message for email confirmation */}
          {(await searchParams).success && (
            <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
              <div className="flex items-start space-x-3">
                <div className="flex-shrink-0">
                  <svg className="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                </div>
                <div className="flex-1">
                  <h3 className="text-sm font-medium text-green-800">
                    注册成功！
                  </h3>
                  <div className="mt-2 text-sm text-green-700">
                    <p>我们已向您的邮箱发送了一封确认邮件。</p>
                    <p className="mt-1">请按照以下步骤完成账户激活：</p>
                    <ol className="mt-2 ml-4 list-decimal space-y-1">
                      <li>打开您的邮箱应用或网页版邮箱</li>
                      <li>查找来自我们的确认邮件（请检查垃圾邮件文件夹）</li>
                      <li>点击邮件中的"确认账户"按钮</li>
                      <li>确认后即可返回登录页面使用您的账户</li>
                    </ol>
                  </div>
                  <div className="mt-4">
                    <Link
                      href="/sign-in"
                      className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-green-700 bg-green-100 hover:bg-green-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 transition-colors"
                    >
                      前往登录页面
                    </Link>
                  </div>
                </div>
              </div>
            </div>
          )}
        </form>
        <div className="relative">
          <div className="absolute inset-0 flex items-center">
            <span className="w-full border-t" />
          </div>
          <div className="relative flex justify-center text-xs uppercase">
            <span className="bg-background px-2 text-muted-foreground">
              Or continue with
            </span>
          </div>
        </div>
        <form action={signUpWithGoogle}>
          <Button
            type="submit"
            variant="outline"
            className="w-full flex items-center justify-center gap-2"
          >
            <svg viewBox="0 0 24 24" className="h-5 w-5">
              <path
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                fill="#4285F4"
              />
              <path
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                fill="#34A853"
              />
              <path
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                fill="#FBBC05"
              />
              <path
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                fill="#EA4335"
              />
            </svg>
            Sign up with Google
          </Button>
        </form>
        <div className="text-sm text-muted-foreground text-center">
          Already have an account?{" "}
          <Link
            href="/sign-in"
            className="text-primary underline underline-offset-4 hover:text-primary/90"
          >
            Sign in
          </Link>
        </div>
      </div>
    </>
  );
}
