import { useState } from "react";
import { Pressable, StyleSheet, Text, TextInput, View } from "react-native";
import { AppCard } from "../../components/AppCard";
import { Screen } from "../../components/Screen";
import { useAppContext } from "../../state/AppContext";
import { palette, radius, spacing } from "../../theme";
import { FuelProduct, FuelStationPreference, FuelType, VehicleProfile, fuelProductLabel, fuelTypeLabel, stationPreferenceLabel } from "../../models/vehicle";

export function VehicleSetupScreen() {
  const { saveProfile } = useAppContext();

  const [make, setMake] = useState("Toyota");
  const [model, setModel] = useState("Camry");
  const [year, setYear] = useState("2022");
  const [fuelType, setFuelType] = useState<FuelType>("gasoline");
  const [mpg, setMpg] = useState("29");
  const [homeArea, setHomeArea] = useState("San Jose, CA");
  const [weeklyMiles, setWeeklyMiles] = useState("210");
  const [commonRoutes, setCommonRoutes] = useState("Downtown commute, South Bay errands, Highway 101");
  const [preferredFuelProduct, setPreferredFuelProduct] = useState<FuelProduct>("regular");
  const [stationPreference, setStationPreference] = useState<FuelStationPreference>("balanced");

  const canSave = Boolean(make.trim() && model.trim() && year.trim() && weeklyMiles.trim());

  const handleSave = () => {
    if (!canSave) {
      return;
    }

    const profile: VehicleProfile = {
      id: `vehicle-${Date.now()}`,
      make: make.trim(),
      model: model.trim(),
      year: Number(year) || new Date().getFullYear(),
      fuelType,
      mpg: Number(mpg) || undefined,
      currentOdometerMiles: 46820,
      homeArea: homeArea.trim(),
      preferredFuelProduct,
      stationPreference,
      prioritizePromos: true,
      weeklyMiles: Number(weeklyMiles) || 0,
      commonRoutes: commonRoutes
        .split(",")
        .map((value) => value.trim())
        .filter(Boolean)
    };

    saveProfile(profile);
  };

  return (
    <Screen>
      <AppCard
        title="ACM2 Copilot Setup"
        subtitle="This new Expo app now feeds a backend-owned Fuel Agent, Maintenance Agent, and Copilot pipeline."
      >
        <View style={styles.fieldGroup}>
          <Text style={styles.label}>Vehicle</Text>
          <TextInput value={make} onChangeText={setMake} placeholder="Make" style={styles.input} />
          <TextInput value={model} onChangeText={setModel} placeholder="Model" style={styles.input} />
          <TextInput value={year} onChangeText={setYear} placeholder="Year" keyboardType="number-pad" style={styles.input} />
        </View>

        <View style={styles.fieldGroup}>
          <Text style={styles.label}>Fuel + Location</Text>
          <View style={styles.optionGrid}>
            {(["gasoline", "diesel", "hybrid", "electric"] as FuelType[]).map((option) => (
              <SelectionChip
                key={option}
                label={fuelTypeLabel[option]}
                selected={fuelType === option}
                onPress={() => setFuelType(option)}
              />
            ))}
          </View>
          <TextInput value={mpg} onChangeText={setMpg} placeholder="MPG" keyboardType="decimal-pad" style={styles.input} />
          <TextInput value={homeArea} onChangeText={setHomeArea} placeholder="Home area" style={styles.input} />
          <TextInput
            value={weeklyMiles}
            onChangeText={setWeeklyMiles}
            placeholder="Weekly miles"
            keyboardType="number-pad"
            style={styles.input}
          />
        </View>

        <View style={styles.fieldGroup}>
          <Text style={styles.label}>Fuel Preferences</Text>
          <View style={styles.optionGrid}>
            {(["regular", "midgrade", "premium", "flexible"] as FuelProduct[]).map((option) => (
              <SelectionChip
                key={option}
                label={fuelProductLabel[option]}
                selected={preferredFuelProduct === option}
                onPress={() => setPreferredFuelProduct(option)}
              />
            ))}
          </View>

          <View style={styles.optionGrid}>
            {(["cheapest", "balanced", "premiumQuality", "promoHunter"] as FuelStationPreference[]).map((option) => (
              <SelectionChip
                key={option}
                label={stationPreferenceLabel[option]}
                selected={stationPreference === option}
                onPress={() => setStationPreference(option)}
              />
            ))}
          </View>

          <TextInput
            value={commonRoutes}
            onChangeText={setCommonRoutes}
            placeholder="Common routes, comma separated"
            style={[styles.input, styles.multiline]}
            multiline
          />
        </View>

        <Pressable style={[styles.button, !canSave && styles.buttonDisabled]} onPress={handleSave} disabled={!canSave}>
          <Text style={styles.buttonText}>Launch ACM2</Text>
        </Pressable>
      </AppCard>
    </Screen>
  );
}

function SelectionChip({
  label,
  selected,
  onPress
}: {
  label: string;
  selected: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable onPress={onPress} style={[styles.chip, selected && styles.chipSelected]}>
      <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  fieldGroup: {
    gap: spacing.sm
  },
  label: {
    fontSize: 14,
    fontWeight: "700",
    color: palette.text
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
  optionGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.sm
  },
  chip: {
    borderRadius: 999,
    borderWidth: 1,
    borderColor: palette.border,
    paddingHorizontal: 14,
    paddingVertical: 10,
    backgroundColor: "#fff"
  },
  chipSelected: {
    backgroundColor: palette.primary,
    borderColor: palette.primary
  },
  chipText: {
    color: palette.text,
    fontWeight: "700"
  },
  chipTextSelected: {
    color: "#fff"
  },
  button: {
    marginTop: spacing.sm,
    backgroundColor: palette.primary,
    borderRadius: radius.sm,
    paddingVertical: 14,
    alignItems: "center"
  },
  buttonDisabled: {
    opacity: 0.5
  },
  buttonText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "800"
  }
});
