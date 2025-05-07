import { useState } from "react";
import { Button, Text, View } from "react-native";

export default function Index() {
  const [isClicked, setIsClicked] = useState(false);

  return (
    <View
      style={{
        flex: 1,
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      <Text>Hello</Text>
      <Button title="Reveal next word" onPress={() => setIsClicked(true)} />
      {isClicked && <Text>World</Text>}
    </View>
  );
}
