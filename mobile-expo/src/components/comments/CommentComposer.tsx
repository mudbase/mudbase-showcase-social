import { Controller, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { View } from "react-native";
import { router } from "expo-router";
import { z } from "zod";
import { useAuth } from "@/hooks/useAuth";
import { useCreateComment } from "@/hooks/useComments";
import { TextField } from "@/components/ui/TextField";
import { Button } from "@/components/ui/Button";

const MAX_COMMENT_LENGTH = 300;

const schema = z.object({
  content: z
    .string()
    .trim()
    .min(1, "Write a comment first")
    .max(MAX_COMMENT_LENGTH, `Keep it under ${MAX_COMMENT_LENGTH} characters`),
});

type FormValues = z.infer<typeof schema>;

export function CommentComposer({ postId }: { postId: string }): React.JSX.Element {
  const { isAuthenticated } = useAuth();
  const createComment = useCreateComment(postId);
  const {
    control,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { content: "" } });

  const onSubmit = async (values: FormValues): Promise<void> => {
    if (!isAuthenticated) {
      router.push("/login");
      return;
    }
    await createComment.mutateAsync(values.content);
    reset({ content: "" });
  };

  return (
    <View className="gap-2">
      <Controller
        control={control}
        name="content"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Comment"
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            multiline
            editable={isAuthenticated}
            placeholder={isAuthenticated ? "Add a comment…" : "Sign in to comment"}
            error={errors.content?.message}
            className="min-h-16"
          />
        )}
      />
      <View className="flex-row justify-end">
        {isAuthenticated ? (
          <Button size="sm" isLoading={createComment.isPending} onPress={handleSubmit(onSubmit)}>
            {createComment.isPending ? "Posting…" : "Comment"}
          </Button>
        ) : (
          <Button size="sm" onPress={() => router.push("/login")}>
            Sign in to comment
          </Button>
        )}
      </View>
    </View>
  );
}
