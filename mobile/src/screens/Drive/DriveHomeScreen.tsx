import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { AppCard } from "../../components/AppCard";
import { MetricPill } from "../../components/MetricPill";
import { Screen } from "../../components/Screen";
import { useAppContext } from "../../state/AppContext";
import { palette, radius, spacing } from "../../theme";
import { currency, formatDuration } from "../../utils/format";
import { DriveStackParamList } from "../../navigation/AppNavigator";

type Props = NativeStackScreenProps<DriveStackParamList, "DriveHome">;

export function DriveHomeScreen({ navigation }: Props) {
  const { profile, trips, maintenanceReminders } = useAppContext();

  const latestTrip = trips[0];
  const maintenanceAttention = maintenanceReminders.length;
  const monthlyFuelSpend = trips.reduce((sum, trip) => sum + (trip.estimatedFuelCost ?? 0), 0);

  return (
    <Screen>
      <AppCard title={profile ? `${profile.year} ${profile.make} ${profile.model}` : "Vehicle"} subtitle="Expo client backed by a dedicated agent API layer.">
        <View style={styles.row}>
          <MetricPill label="Home Area" value={profile?.homeArea ?? "--"} />
          <MetricPill label="Weekly Miles" value={String(profile?.weeklyMiles ?? "--")} />
        </View>
        <View style={styles.row}>
          <MetricPill label="Fuel Spend" value={currency(monthlyFuelSpend)} />
          <MetricPill label="Maint Alerts" value={String(maintenanceAttention)} />
        </View>
      </AppCard>

      <AppCard title="Workspace Shift" subtitle="Fuel, maintenance, and copilot intelligence now come from the backend instead of living in the app bundle.">
        <Text style={styles.bodyText}>Fuel Intel now reads structured cards from the Fuel Agent backend.</Text>
        <Text style={styles.bodyText}>Maintenance reads adjusted estimates from the Maintenance Agent backend.</Text>
        <Text style={styles.bodyText}>Copilot merges both into daily briefs, typed Q&A, and voice summaries.</Text>
      </AppCard>

      {latestTrip ? (
        <AppCard title="Latest Trip" subtitle={new Date(latestTrip.endedAt).toLocaleString()}>
          <View style={styles.row}>
            <MetricPill label="Duration" value={formatDuration(latestTrip.durationSeconds)} />
            <MetricPill label="Distance" value={`${latestTrip.distanceMiles?.toFixed(1) ?? "--"} mi`} />
            <MetricPill label="Fuel" value={currency(latestTrip.estimatedFuelCost)} />
          </View>
          <Text style={styles.bodyText}>{latestTrip.aiOverallTip ?? "Trip AI insight will show here after backend parity is complete."}</Text>
          <Pressable style={styles.button} onPress={() => navigation.navigate("TripComplete")}>
            <Text style={styles.buttonText}>Open Trip Summary</Text>
          </Pressable>
        </AppCard>
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    gap: spacing.sm
  },
  bodyText: {
    color: palette.mutedText,
    lineHeight: 20
  },
  button: {
    marginTop: spacing.sm,
    borderRadius: radius.sm,
    backgroundColor: palette.primary,
    paddingVertical: 12,
    alignItems: "center"
  },
  buttonText: {
    color: "#fff",
    fontWeight: "800"
  }
});
