import { useCallback, useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";
import { AppCard } from "../../components/AppCard";
import { MetricPill } from "../../components/MetricPill";
import { Screen } from "../../components/Screen";
import { StructuredCard } from "../../components/StructuredCard";
import { MaintenanceAnalysis } from "../../models/agent";
import { maintenanceServiceLabel } from "../../models/trip";
import { MaintenanceAgentClient } from "../../services/backend/MaintenanceAgentClient";
import { useAppContext } from "../../state/AppContext";
import { palette, radius, spacing } from "../../theme";
import { currency } from "../../utils/format";

const client = new MaintenanceAgentClient();

export function MaintenanceScreen() {
  const { profile, maintenanceExpenses, maintenanceReminders, trips } = useAppContext();
  const [analysis, setAnalysis] = useState<MaintenanceAnalysis | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const request = useMemo(() => {
    if (!profile) {
      return null;
    }

    return {
      userId: profile.id,
      profile,
      reminders: maintenanceReminders,
      trips,
      expenses: maintenanceExpenses
    };
  }, [maintenanceExpenses, maintenanceReminders, profile, trips]);

  const loadAnalysis = useCallback(async () => {
    if (!request) {
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await client.analyze(request);
      setAnalysis(response);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Could not load maintenance analysis.");
    } finally {
      setLoading(false);
    }
  }, [request]);

  useEffect(() => {
    void loadAnalysis();
  }, [loadAnalysis]);

  return (
    <Screen>
      <AppCard title="Maintenance Agent" subtitle="Adjusted service timing now comes from the Express backend, not from app-bundled logic.">
        <Text style={styles.bodyText}>The backend combines vehicle profile, service history, driving behavior, and future Redis memory before returning display-ready cards.</Text>
        <Pressable style={styles.button} onPress={() => void loadAnalysis()}>
          <Text style={styles.buttonText}>Refresh Maintenance Analysis</Text>
        </Pressable>
      </AppCard>

      <AppCard title="Recent Spend" subtitle="Manual maintenance purchases stay local to the mobile client until you wire shared backend persistence.">
        <View style={styles.row}>
          <MetricPill
            label="Entries"
            value={String(maintenanceExpenses.length)}
          />
          <MetricPill
            label="Spend"
            value={currency(maintenanceExpenses.reduce((sum, expense) => sum + expense.totalCost, 0))}
          />
        </View>
      </AppCard>

      {loading ? <ActivityIndicator size="large" color={palette.primary} /> : null}

      {error ? (
        <AppCard title="Maintenance Agent Error">
          <Text style={styles.errorText}>{error}</Text>
        </AppCard>
      ) : null}

      {analysis ? (
        <>
          <AppCard title="Adjusted Estimates" subtitle="These are the normalized maintenance outputs the app can render automatically.">
            {analysis.estimates.map((estimate) => (
              <View key={estimate.serviceType} style={styles.estimateRow}>
                <View style={{ flex: 1, gap: 4 }}>
                  <Text style={styles.estimateTitle}>
                    {maintenanceServiceLabel[estimate.serviceType as keyof typeof maintenanceServiceLabel] ?? estimate.serviceType}
                  </Text>
                  <Text style={styles.bodyText}>{estimate.reason}</Text>
                  <Text style={styles.bodyText}>{estimate.recommendedAction}</Text>
                </View>
                <View style={styles.estimateMeta}>
                  <Text style={styles.metaStrong}>{estimate.dueInMiles} mi</Text>
                  <Text style={styles.metaMuted}>{estimate.dueDateLabel}</Text>
                </View>
              </View>
            ))}
          </AppCard>

          {analysis.cards.map((card) => (
            <StructuredCard key={card.id} card={card} />
          ))}

          <AppCard title="Notification Decisions">
            {analysis.actions.length ? (
              analysis.actions.map((action) => (
                <View key={action.id} style={styles.actionRow}>
                  <Text style={styles.estimateTitle}>{action.title}</Text>
                  <Text style={styles.bodyText}>{action.description}</Text>
                </View>
              ))
            ) : (
              <Text style={styles.bodyText}>No urgent maintenance alert needs to fire from the current analysis.</Text>
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
    gap: spacing.sm
  },
  bodyText: {
    color: palette.mutedText,
    lineHeight: 20
  },
  button: {
    marginTop: spacing.sm,
    backgroundColor: palette.accent,
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
  estimateRow: {
    flexDirection: "row",
    gap: spacing.md,
    paddingVertical: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: palette.border
  },
  estimateTitle: {
    color: palette.text,
    fontWeight: "800"
  },
  estimateMeta: {
    alignItems: "flex-end",
    gap: 4
  },
  metaStrong: {
    color: palette.text,
    fontWeight: "800"
  },
  metaMuted: {
    color: palette.mutedText,
    fontSize: 12
  },
  actionRow: {
    gap: 4
  }
});
