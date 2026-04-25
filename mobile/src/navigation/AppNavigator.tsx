import { Ionicons } from "@expo/vector-icons";
import { NavigationContainer } from "@react-navigation/native";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { ActivityIndicator, View } from "react-native";
import { useAppContext } from "../state/AppContext";
import { palette } from "../theme";
import { CopilotHomeScreen } from "../screens/Copilot/CopilotHomeScreen";
import { CostTrackerScreen } from "../screens/Cost/CostTrackerScreen";
import { DriveHomeScreen } from "../screens/Drive/DriveHomeScreen";
import { FuelIntelScreen } from "../screens/Fuel/FuelIntelScreen";
import { MaintenanceScreen } from "../screens/Maintenance/MaintenanceScreen";
import { VehicleSetupScreen } from "../screens/Onboarding/VehicleSetupScreen";
import { TripCompleteScreen } from "../screens/Trip/TripCompleteScreen";

export type DriveStackParamList = {
  DriveHome: undefined;
  TripComplete: undefined;
};

const RootStack = createNativeStackNavigator();
const DriveStack = createNativeStackNavigator<DriveStackParamList>();
const Tab = createBottomTabNavigator();

function DriveStackNavigator() {
  return (
    <DriveStack.Navigator>
      <DriveStack.Screen name="DriveHome" component={DriveHomeScreen} options={{ title: "Drive" }} />
      <DriveStack.Screen name="TripComplete" component={TripCompleteScreen} options={{ title: "Trip Complete" }} />
    </DriveStack.Navigator>
  );
}

function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarActiveTintColor: palette.primary,
        tabBarInactiveTintColor: palette.mutedText,
        tabBarStyle: {
          backgroundColor: palette.surface,
          borderTopColor: palette.border
        },
        tabBarIcon: ({ color, size }) => {
          const iconMap: Record<string, keyof typeof Ionicons.glyphMap> = {
            Drive: "car-sport",
            Fuel: "newspaper",
            Costs: "bar-chart",
            Maintenance: "construct",
            Copilot: "sparkles"
          };

          return <Ionicons name={iconMap[route.name] ?? "ellipse"} size={size} color={color} />;
        }
      })}
    >
      <Tab.Screen name="Drive" component={DriveStackNavigator} />
      <Tab.Screen name="Fuel" component={FuelIntelScreen} options={{ title: "Fuel Intel" }} />
      <Tab.Screen name="Costs" component={CostTrackerScreen} options={{ title: "Cost Tracker" }} />
      <Tab.Screen name="Maintenance" component={MaintenanceScreen} />
      <Tab.Screen name="Copilot" component={CopilotHomeScreen} />
    </Tab.Navigator>
  );
}

export function AppNavigator() {
  const { isHydrating, profile } = useAppContext();

  if (isHydrating) {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: palette.background }}>
        <ActivityIndicator size="large" color={palette.primary} />
      </View>
    );
  }

  return (
    <NavigationContainer>
      <RootStack.Navigator screenOptions={{ headerShown: false }}>
        {profile ? (
          <RootStack.Screen name="MainTabs" component={MainTabs} />
        ) : (
          <RootStack.Screen name="Onboarding" component={VehicleSetupScreen} />
        )}
      </RootStack.Navigator>
    </NavigationContainer>
  );
}
