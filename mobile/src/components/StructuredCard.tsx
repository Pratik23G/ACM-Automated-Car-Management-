import { StyleSheet, Text, View } from "react-native";
import { CopilotCard } from "../models/agent";
import { palette, radius, spacing } from "../theme";

interface StructuredCardProps {
  card: CopilotCard;
}

const toneStyles = {
  info: { backgroundColor: "#edf7f7", borderColor: "#b8dddd" },
  success: { backgroundColor: "#eef8f1", borderColor: "#b9d9c1" },
  warning: { backgroundColor: "#fff7eb", borderColor: "#f2d3a6" },
  critical: { backgroundColor: "#fff0ee", borderColor: "#efc0bb" }
} as const;

export function StructuredCard({ card }: StructuredCardProps) {
  const tone = toneStyles[card.tone];

  return (
    <View style={[styles.card, tone]}>
      <Text style={styles.title}>{card.title}</Text>
      <Text style={styles.body}>{card.body}</Text>

      {card.items?.length ? (
        <View style={styles.itemList}>
          {card.items.map((item) => (
            <View key={`${card.id}-${item.label}`} style={styles.itemRow}>
              <Text style={styles.itemLabel}>{item.label}</Text>
              <Text style={styles.itemValue}>{item.value}</Text>
            </View>
          ))}
        </View>
      ) : null}

      {card.tags?.length ? (
        <View style={styles.tagsRow}>
          {card.tags.map((tag) => (
            <View key={`${card.id}-${tag}`} style={styles.tag}>
              <Text style={styles.tagText}>{tag}</Text>
            </View>
          ))}
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: radius.md,
    borderWidth: 1,
    padding: spacing.md,
    gap: spacing.sm
  },
  title: {
    color: palette.text,
    fontSize: 17,
    fontWeight: "800"
  },
  body: {
    color: palette.mutedText,
    fontSize: 14,
    lineHeight: 20
  },
  itemList: {
    gap: spacing.xs
  },
  itemRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    gap: spacing.sm
  },
  itemLabel: {
    flex: 1,
    color: palette.mutedText,
    fontSize: 13
  },
  itemValue: {
    color: palette.text,
    fontSize: 13,
    fontWeight: "700"
  },
  tagsRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.xs
  },
  tag: {
    borderRadius: 999,
    paddingHorizontal: spacing.sm,
    paddingVertical: 4,
    backgroundColor: "#ffffff"
  },
  tagText: {
    color: palette.sky,
    fontSize: 12,
    fontWeight: "700"
  }
});
