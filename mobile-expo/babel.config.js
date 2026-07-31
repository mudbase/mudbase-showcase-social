module.exports = function babelConfig(api) {
  api.cache(true);
  return {
    presets: [
      ["babel-preset-expo", { jsxImportSource: "nativewind" }],
      "nativewind/babel",
    ],
    // react-native-worklets/plugin must be listed last — it rewrites worklet
    // closures produced by react-native-reanimated v4 (which no longer ships
    // its own babel plugin; that responsibility moved to react-native-worklets).
    plugins: ["react-native-worklets/plugin"],
  };
};
