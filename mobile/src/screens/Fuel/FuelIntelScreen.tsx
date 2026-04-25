import { useCallback, useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";
import { AppCard } from "../../components/AppCard";
import { MetricPill } from "../../components/MetricPill";
import { Screen } from "../../components/Screen";
import { StructuredCard } from "../../components/StructuredCard";
import { FuelSummary } from "../../models/agent";
import { FuelAgentClient } from "../../services/backend/FuelAgentClient";
import { useAppContext } from "../../state/AppContext";
import { palette, radius, spacing } from "../../theme";
import { currency } from "../../utils/format";

const client = new FuelAgentClient();

export function FuelIntelScreen() {
  const { profile, trips, fuelLogs } = useAppContext();
  const [summary, setSummary] = useState<FuelSummary | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const request = useMemo(() => {
    if (!profile) {
      return null;
    }
    return {
      userId: profile.id,
      profile,
      trips,
      fuelLogs
    };
  }, [fuelLogs, profile, trips]);

  const loadSummary = useCallback(async () => {
    if (!request) {
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const response = await client.getSummary(request);
      setSummary(response);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Could not load fuel intelligence.");
    } finally {
      setLoading(false);
    }
  }, [request]);

  useEffect(() => {
    void loadSummary();
  }, [loadSummary]);

  return (
    <Screen>
      <AppCard title="Fuel Intel" subtitle="Tinyfish-backed station intelligence and market signals come through the Express backend.">
        <Text style={styles.bodyText}>The mobile app only sends profile and trip context. Secrets and provider calls stay on the backend.</Text>
        <Pressable style={styles.button} onPress={() => void loadSummary()}>
          <Text style={styles.buttonText}>Refresh Fuel Agent</Text>
        </Pressable>
      </AppCard>

      {loading ? (
        <ActivityIndicator size="large" color={palette.primary} />
      ) : null}

      {error ? (
        <AppCard title="Fuel Agent Error">
          <Text style={styles.errorText}>{error}</Text>
        </AppCard>
      ) : null}

      {summary ? (
        <>
          <AppCard title={summary.newsHeadline} subtitle={`${summary.areaLabel} • ${summary.fuelProduct}`}>
            <View style={styles.row}>
              <MetricPill label="Local Avg" value={currency(summary.localAveragePrice)} />
              <MetricPill label="Weekly" value={currency(summary.weeklyCost)} />
              <MetricPill label="Monthly" value={currency(summary.monthlyCost)} />
            </View>
            <View style={styles.row}>
              <MetricPill label="Yearly" value={currency(summary.yearlyCost)} />
              <MetricPill label="Savings" value={currency(summary.estimatedSavings)} />
            </View>
          </AppCard>

          <AppCard title="Station Signals" subtitle="Rendered from structured backend data, ready for Tinyfish integration.">
            <Text style={styles.stationTitle}>{summary.cheapestStation.name}</Text>
            <Text style={styles.bodyText}>
              Cheapest right now in {summary.cheapestStation.areaLabel} at {currency(summary.cheapestStation.price)}.
            </Text>
            <Text style={styles.bodyText}>{summary.cheapestStation.savingsNote}</Text>
            {summary.premiumStation ? (
              <Text style={styles.bodyText}>
                Quality pick: {summary.premiumStation.name} with {summary.premiumStation.qualitySignal}.
              </Text>
            ) : null}
          </AppCard>

          {summary.cards.map((card) => (
            <StructuredCard key={card.id} card={card} />
          ))}

          <AppCard title="Fuel Notifications" subtitle="These decisions are returned by the backend and can later map to push notifications.">
            {summary.actions.length ? (
              summary.actions.map((action) => (
                <View key={action.id} style={styles.actionRow}>
                  <Text style={styles.actionTitle}>{action.title}</Text>
                  <Text style={styles.bodyText}>{action.description}</Text>
                </View>
              ))
            ) : (
              <Text style={styles.bodyText}>No immediate notification recommendation was returned for this snapshot.</Text>
            )}
          </AppCard>
        </>
      ) : null}
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
  },
  button: {
    marginTop: spacing.sm,
    backgroundColor: palette.primary,
    borderRadius: radius.sm,
    paddingVertical: 12,
    alignItems: "center"
  },
  buttonText: {
    color: "#fff",
    fontWeight: "800"
  },
  errorText: {
    color: palette.danger
  },
  stationTitle: {
    color: palette.text,
    fontSize: 17,
    fontWeight: "800"
  },
  actionRow: {
    gap: 4,
    paddingVertical: 6,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: palette.border
  },
  actionTitle: {
    color: palette.text,
    fontWeight: "700"
  }
});
