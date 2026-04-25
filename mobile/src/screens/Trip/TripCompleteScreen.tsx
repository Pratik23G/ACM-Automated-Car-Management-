import { StyleSheet, Text, View } from "react-native";
import { AppCard } from "../../components/AppCard";
import { MetricPill } from "../../components/MetricPill";
import { Screen } from "../../components/Screen";
import { useAppContext } from "../../state/AppContext";
import { palette, spacing } from "../../theme";
import { currency, formatDuration } from "../../utils/format";

export function TripCompleteScreen() {
  const { trips } = useAppContext();
  const trip = trips[0];

  if (!trip) {
    return (
      <Screen>
        <AppCard title="Trip Complete">
          <Text style={styles.bodyText}>No trip has been recorded yet.</Text>
        </AppCard>
      </Screen>
    );
  }

  return (
    <Screen>
      <AppCard title="Trip Summary" subtitle={new Date(trip.endedAt).toLocaleString()}>
        <View style={styles.row}>
          <MetricPill label="Duration" value={formatDuration(trip.durationSeconds)} />
          <MetricPill label="Distance" value={`${trip.distanceMiles?.toFixed(1) ?? "--"} mi`} />
          <MetricPill label="Fuel" value={currency(trip.estimatedFuelCost)} />
        </View>
        <Text style={styles.bodyText}>{trip.aiTripSummary}</Text>
      </AppCard>

      <AppCard title="Driving Events">
        <View style={styles.row}>
          <MetricPill label="Hard Brakes" value={String(trip.hardBrakes)} />
          <MetricPill label="Sharp Turns" value={String(trip.sharpTurns)} />
          <MetricPill label="Aggressive Accels" value={String(trip.aggressiveAccels)} />
        </View>
        <Text style={styles.bodyText}>{trip.aiDrivingBehavior}</Text>
      </AppCard>

      <AppCard title="Fuel + Road Impact">
        <Text style={styles.bodyText}>{trip.aiFuelInsight}</Text>
        <Text style={styles.bodyText}>{trip.aiRoadImpact}</Text>
        <Text style={styles.bodyText}>{trip.aiOverallTip}</Text>
      </AppCard>
    </Screen>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    gap: spacing.sm,
    flexWrap: "wrap"
  },
  bodyText: {
    color: palette.mutedText,
    lineHeight: 20
  }
});
