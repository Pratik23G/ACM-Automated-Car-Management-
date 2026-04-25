import { StatusBar } from "react-native";
import { AppNavigator } from "./src/navigation/AppNavigator";
import { AppProvider } from "./src/state/AppContext";

export default function App() {
  return (
    <AppProvider>
      <StatusBar barStyle="dark-content" />
      <AppNavigator />
    </AppProvider>
  );
}
