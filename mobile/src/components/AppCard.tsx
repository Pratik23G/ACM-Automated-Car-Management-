import { PropsWithChildren } from "react";
import { StyleSheet, Text, View } from "react-native";
import { palette, radius, spacing } from "../theme";

interface AppCardProps extends PropsWithChildren {
  title: string;
  subtitle?: string;
}

export function AppCard({ title, subtitle, children }: AppCardProps) {
  return (
    <View style={styles.card}>
      <Text style={styles.title}>{title}</Text>
      {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
      <View style={styles.body}>{children}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: palette.surface,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: palette.border,
    padding: spacing.md,
    gap: spacing.sm
  },
  title: {
    color: palette.text,
    fontSize: 18,
    fontWeight: "800"
  },
  subtitle: {
    color: palette.mutedText,
    fontSize: 13,
    lineHeight: 18
  },
  body: {
    gap: spacing.sm
  }
});
