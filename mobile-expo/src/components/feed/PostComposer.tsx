import { useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Pressable, Text, View } from "react-native";
import { Image } from "expo-image";
import * as ImagePicker from "expo-image-picker";
import { router } from "expo-router";
import { ImagePlus, X } from "lucide-react-native";
import { z } from "zod";
import { useAuth } from "@/hooks/useAuth";
import { useCreatePost } from "@/hooks/usePostsFeed";
import { mudbaseClient, MudbaseApiError } from "@/api/client";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { TextField } from "@/components/ui/TextField";
import { ErrorNotice } from "@/components/ui/ErrorNotice";

const MAX_CONTENT_LENGTH = 500;

const schema = z.object({
  content: z
    .string()
    .trim()
    .min(1, "Write something first")
    .max(MAX_CONTENT_LENGTH, `Keep it under ${MAX_CONTENT_LENGTH} characters`),
});

type FormValues = z.infer<typeof schema>;

interface PickedImage {
  uri: string;
  name: string;
  mimeType: string;
}

export function PostComposer(): React.JSX.Element {
  const { isAuthenticated } = useAuth();
  const createPost = useCreatePost();
  const [pickedImage, setPickedImage] = useState<PickedImage | null>(null);
  const [imageNotice, setImageNotice] = useState<string | null>(null);
  const [isUploadingImage, setIsUploadingImage] = useState(false);

  const {
    control,
    handleSubmit,
    reset,
    watch,
    formState: { errors },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { content: "" } });

  const content = watch("content") ?? "";

  const pickImage = async (): Promise<void> => {
    setImageNotice(null);
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      setImageNotice("Photo library access was denied — enable it in Settings to attach an image.");
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ["images"],
      quality: 0.7,
      allowsEditing: true,
      aspect: [4, 3],
    });
    if (result.canceled || !result.assets[0]) return;
    const asset = result.assets[0];
    const extension = asset.uri.split(".").pop()?.toLowerCase() ?? "jpg";
    setPickedImage({
      uri: asset.uri,
      name: asset.fileName ?? `post-image.${extension}`,
      mimeType: asset.mimeType ?? `image/${extension === "jpg" ? "jpeg" : extension}`,
    });
  };

  const onSubmit = async (values: FormValues): Promise<void> => {
    if (!isAuthenticated) {
      router.push("/login");
      return;
    }

    let imageUrl: string | undefined;
    if (pickedImage) {
      setIsUploadingImage(true);
      try {
        imageUrl = await mudbaseClient.uploadPostImage(pickedImage);
      } catch (err) {
        // Verified live, real platform constraint (see client.ts's uploadPostImage doc comment
        // and ../plan/build-plan.md "Known limitations"): bucket upload is unreachable for any
        // project end-user role. Post the text anyway rather than blocking the whole action on
        // a permission this account can never satisfy.
        const message =
          err instanceof MudbaseApiError
            ? err.message
            : "Image upload failed — posting without the photo.";
        setImageNotice(message);
      } finally {
        setIsUploadingImage(false);
      }
    }

    await createPost.mutateAsync({ content: values.content, imageUrl });
    reset({ content: "" });
    setPickedImage(null);
  };

  const isBusy = createPost.isPending || isUploadingImage;

  return (
    <Card className="gap-3">
      {imageNotice && <ErrorNotice message={imageNotice} />}
      <Controller
        control={control}
        name="content"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="What's on your mind?"
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            multiline
            numberOfLines={3}
            editable={isAuthenticated}
            placeholder={isAuthenticated ? "Share something…" : "Sign in to post"}
            error={errors.content?.message}
            className="min-h-20"
          />
        )}
      />
      <Text className="text-right text-xs text-muted-foreground">
        {content.length}/{MAX_CONTENT_LENGTH}
      </Text>

      {pickedImage && (
        <View className="relative aspect-[4/3] w-full overflow-hidden rounded-md border border-border">
          <Image source={{ uri: pickedImage.uri }} style={{ width: "100%", height: "100%" }} contentFit="cover" />
          <Pressable
            onPress={() => setPickedImage(null)}
            accessibilityRole="button"
            accessibilityLabel="Remove photo"
            className="absolute right-2 top-2 h-8 w-8 items-center justify-center rounded-full bg-black/60"
          >
            <X size={16} color="#ffffff" />
          </Pressable>
        </View>
      )}

      <View className="flex-row items-center justify-between">
        <Button
          variant="outline"
          size="sm"
          icon={<ImagePlus size={16} color="#181c25" />}
          disabled={!isAuthenticated}
          onPress={() => void pickImage()}
        >
          {pickedImage ? "Change photo" : "Add photo"}
        </Button>
        {isAuthenticated ? (
          <Button size="sm" isLoading={isBusy} onPress={handleSubmit(onSubmit)}>
            {isBusy ? "Posting…" : "Post"}
          </Button>
        ) : (
          <Button size="sm" onPress={() => router.push("/login")}>
            Sign in to post
          </Button>
        )}
      </View>
    </Card>
  );
}
