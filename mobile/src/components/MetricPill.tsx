import { StyleSheet, Text, View } from "react-native";
import { palette, radius, spacing } from "../theme";

interface MetricPillProps {
  label: string;
  value: string;
}

export function MetricPill({ label, value }: MetricPillProps) {
  return (
    <View style={styles.pill}>
      <Text style={styles.label}>{label}</Text>
      <Text style={styles.value}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  pill: {
    flex: 1,
    minWidth: 92,
    padding: spacing.sm,
    borderRadius: radius.sm,
    backgroundColor: palette.surfaceStrong,
    borderWidth: 1,
    borderColor: palette.border,
    gap: 2
  },
  label: {
    color: palette.mutedText,
    fontSize: 12
  },
  value: {
    color: palette.text,
    fontSize: 16,
    fontWeight: "700"
  }
});
