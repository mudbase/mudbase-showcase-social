import { Controller, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { View } from "react-native";
import { z } from "zod";
import { useAuth } from "@/hooks/useAuth";
import { TextField } from "@/components/ui/TextField";
import { Button } from "@/components/ui/Button";
import { ErrorNotice } from "@/components/ui/ErrorNotice";

const loginSchema = z.object({
  email: z.string().email("Enter a valid email address"),
  password: z.string().min(1, "Password is required"),
});

type LoginFormValues = z.infer<typeof loginSchema>;

export function LoginForm({ onSuccess }: { onSuccess: () => void }): React.JSX.Element {
  const { login, isSubmitting, error, clearError } = useAuth();
  const {
    control,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginFormValues>({ resolver: zodResolver(loginSchema), defaultValues: { email: "", password: "" } });

  const onSubmit = async (values: LoginFormValues): Promise<void> => {
    clearError();
    const ok = await login(values.email, values.password);
    if (ok) onSuccess();
  };

  return (
    <View className="gap-4">
      {error && <ErrorNotice message={error} />}
      <Controller
        control={control}
        name="email"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Email"
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            keyboardType="email-address"
            autoCapitalize="none"
            autoComplete="email"
            error={errors.email?.message}
          />
        )}
      />
      <Controller
        control={control}
        name="password"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Password"
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            secureTextEntry
            autoComplete="current-password"
            error={errors.password?.message}
          />
        )}
      />
      <Button onPress={handleSubmit(onSubmit)} isLoading={isSubmitting}>
        {isSubmitting ? "Signing in…" : "Sign in"}
      </Button>
    </View>
  );
}
