import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, TextInput, View } from "react-native";
import { AppCard } from "../../components/AppCard";
import { MetricPill } from "../../components/MetricPill";
import { Screen } from "../../components/Screen";
import { useAppContext } from "../../state/AppContext";
import { palette, radius, spacing } from "../../theme";
import { currency, formatDate } from "../../utils/format";

type TrackerMode = "fuel" | "maintenance";
type Period = "daily" | "weekly" | "monthly" | "yearly";

export function CostTrackerScreen() {
  const { fuelLogs, maintenanceExpenses, addMaintenanceExpense } = useAppContext();
  const [mode, setMode] = useState<TrackerMode>("fuel");
  const [period, setPeriod] = useState<Period>("weekly");
  const [itemName, setItemName] = useState("");
  const [location, setLocation] = useState("");
  const [price, setPrice] = useState("");
  const [notes, setNotes] = useState("");

  const fuelEntries = useMemo(() => filterByPeriod(fuelLogs, period, "loggedAt"), [fuelLogs, period]);
  const maintenanceEntries = useMemo(
    () => filterByPeriod(maintenanceExpenses, period, "purchasedAt"),
    [maintenanceExpenses, period]
  );

  const handleAddMaintenanceExpense = () => {
    if (!itemName.trim() || !location.trim() || !price.trim()) {
      return;
    }

    addMaintenanceExpense({
      id: `expense-${Date.now()}`,
      purchasedAt: new Date().toISOString(),
      category: "Manual",
      itemName: itemName.trim(),
      purchaseLocation: location.trim(),
      totalCost: Number(price) || 0,
      notes: notes.trim() || undefined
    });

    setItemName("");
    setLocation("");
    setPrice("");
    setNotes("");
  };

  const fuelTotal = fuelEntries.reduce((sum, entry) => sum + entry.totalCost, 0);
  const maintenanceTotal = maintenanceEntries.reduce((sum, entry) => sum + entry.totalCost, 0);

  return (
    <Screen>
      <AppCard title="Cost Tracker" subtitle="Fuel and maintenance costs now sit side-by-side in one Expo tab, with agent-ready data underneath.">
        <View style={styles.switchRow}>
          <ModeButton label="Fuel Costs" active={mode === "fuel"} onPress={() => setMode("fuel")} />
          <ModeButton label="Maintenance Costs" active={mode === "maintenance"} onPress={() => setMode("maintenance")} />
        </View>
        <View style={styles.switchRow}>
          {(["daily", "weekly", "monthly", "yearly"] as Period[]).map((value) => (
            <ModeButton key={value} label={capitalize(value)} active={period === value} onPress={() => setPeriod(value)} small />
          ))}
        </View>
      </AppCard>

      {mode === "fuel" ? (
        <>
          <AppCard title={`${capitalize(period)} Fuel Costs`} subtitle="Driven from locally stored fill-up logs while backend fuel cards focus on live intelligence.">
            <View style={styles.row}>
              <MetricPill label="Entries" value={String(fuelEntries.length)} />
              <MetricPill label="Spend" value={currency(fuelTotal)} />
              <MetricPill
                label="Avg Fill"
                value={fuelEntries.length ? currency(fuelTotal / fuelEntries.length) : "--"}
              />
            </View>
          </AppCard>

          <AppCard title="Recent Fill-Ups">
            {fuelEntries.length ? (
              fuelEntries.map((entry) => (
                <View key={entry.id} style={styles.listRow}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.titleText}>{entry.stationName}</Text>
                    <Text style={styles.bodyText}>
                      {entry.areaLabel} • {entry.fuelProduct}
                    </Text>
                  </View>
                  <View style={{ alignItems: "flex-end" }}>
                    <Text style={styles.titleText}>{currency(entry.totalCost)}</Text>
                    <Text style={styles.bodyText}>{formatDate(entry.loggedAt)}</Text>
                  </View>
                </View>
              ))
            ) : (
              <Text style={styles.bodyText}>No fill-ups were logged in this period yet.</Text>
            )}
          </AppCard>
        </>
      ) : (
        <>
          <AppCard title={`${capitalize(period)} Maintenance Costs`} subtitle="Manual parts and service entries remain structured so the Maintenance Agent can use them later.">
            <View style={styles.row}>
              <MetricPill label="Entries" value={String(maintenanceEntries.length)} />
              <MetricPill label="Spend" value={currency(maintenanceTotal)} />
              <MetricPill
                label="Avg Entry"
                value={maintenanceEntries.length ? currency(maintenanceTotal / maintenanceEntries.length) : "--"}
              />
            </View>
          </AppCard>

          <AppCard title="Add Manual Maintenance Cost">
            <TextInput value={itemName} onChangeText={setItemName} placeholder="Item or service" style={styles.input} />
            <TextInput value={location} onChangeText={setLocation} placeholder="Location" style={styles.input} />
            <TextInput value={price} onChangeText={setPrice} placeholder="Price" keyboardType="decimal-pad" style={styles.input} />
            <TextInput value={notes} onChangeText={setNotes} placeholder="Notes" style={[styles.input, styles.multiline]} multiline />
            <Pressable style={styles.primaryButton} onPress={handleAddMaintenanceExpense}>
              <Text style={styles.primaryButtonText}>Save Maintenance Entry</Text>
            </Pressable>
          </AppCard>

          <AppCard title="Recent Maintenance Purchases">
            {maintenanceEntries.length ? (
              maintenanceEntries.map((entry) => (
                <View key={entry.id} style={styles.listRow}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.titleText}>{entry.itemName}</Text>
                    <Text style={styles.bodyText}>
                      {entry.purchaseLocation} • {entry.category}
                    </Text>
                    {entry.notes ? <Text style={styles.bodyText}>{entry.notes}</Text> : null}
                  </View>
                  <View style={{ alignItems: "flex-end" }}>
                    <Text style={styles.titleText}>{currency(entry.totalCost)}</Text>
                    <Text style={styles.bodyText}>{formatDate(entry.purchasedAt)}</Text>
                  </View>
                </View>
              ))
            ) : (
              <Text style={styles.bodyText}>No maintenance purchases were logged in this period yet.</Text>
            )}
          </AppCard>
        </>
      )}
    </Screen>
  );
}

function filterByPeriod<T extends Record<string, unknown>>(items: T[], period: Period, field: keyof T): T[] {
  const now = Date.now();
  const windows: Record<Period, number> = {
    daily: 1,
    weekly: 7,
    monthly: 31,
    yearly: 365
  };

  return items.filter((item) => {
    const rawValue = item[field];
    if (typeof rawValue !== "string") {
      return false;
    }
    const value = new Date(rawValue).getTime();
    return now - value <= windows[period] * 86_400_000;
  });
}

function ModeButton({
  label,
  active,
  onPress,
  small = false
}: {
  label: string;
  active: boolean;
  onPress: () => void;
  small?: boolean;
}) {
  return (
    <Pressable onPress={onPress} style={[styles.modeButton, active && styles.modeButtonActive, small && styles.modeButtonSmall]}>
      <Text style={[styles.modeButtonText, active && styles.modeButtonTextActive]}>{label}</Text>
    </Pressable>
  );
}

function capitalize(value: string) {
  return `${value.slice(0, 1).toUpperCase()}${value.slice(1)}`;
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    gap: spacing.sm,
    flexWrap: "wrap"
  },
  switchRow: {
    flexDirection: "row",
    gap: spacing.sm,
    flexWrap: "wrap"
  },
  modeButton: {
    flex: 1,
    minWidth: 110,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: palette.border,
    backgroundColor: "#fff",
    paddingVertical: 12,
    paddingHorizontal: 14,
    alignItems: "center"
  },
  modeButtonSmall: {
    flex: 0
  },
  modeButtonActive: {
    backgroundColor: palette.primary,
    borderColor: palette.primary
  },
  modeButtonText: {
    color: palette.text,
    fontWeight: "700"
  },
  modeButtonTextActive: {
    color: "#fff"
  },
  input: {
    backgroundColor: "#fff",
    borderRadius: radius.sm,
    borderWidth: 1,
    borderColor: palette.border,
    paddingHorizontal: spacing.md,
    paddingVertical: 12,
    color: palette.text
  },
  multiline: {
    minHeight: 84,
    textAlignVertical: "top"
  },
  primaryButton: {
    backgroundColor: palette.primary,
    borderRadius: radius.sm,
    paddingVertical: 12,
    alignItems: "center"
  },
  primaryButtonText: {
    color: "#fff",
    fontWeight: "800"
  },
  listRow: {
    flexDirection: "row",
    gap: spacing.sm,
    paddingVertical: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: palette.border
  },
  titleText: {
    color: palette.text,
    fontWeight: "800"
  },
  bodyText: {
    color: palette.mutedText,
    lineHeight: 19
  }
});
