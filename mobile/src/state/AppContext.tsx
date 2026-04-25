import AsyncStorage from "@react-native-async-storage/async-storage";
import { PropsWithChildren, createContext, useContext, useEffect, useMemo, useState } from "react";
import { makeSeedFuelLogs, makeSeedMaintenanceExpenses, makeSeedMaintenanceReminders, makeSeedTrips } from "../data/seed";
import { FuelLog, MaintenanceExpense, MaintenanceReminder, TripResult } from "../models/trip";
import { VehicleProfile } from "../models/vehicle";

const STORAGE_KEY = "acm2-mobile-state";

interface PersistedState {
  profile: VehicleProfile | null;
  trips: TripResult[];
  fuelLogs: FuelLog[];
  maintenanceReminders: MaintenanceReminder[];
  maintenanceExpenses: MaintenanceExpense[];
}

interface AppContextValue {
  isHydrating: boolean;
  profile: VehicleProfile | null;
  trips: TripResult[];
  fuelLogs: FuelLog[];
  maintenanceReminders: MaintenanceReminder[];
  maintenanceExpenses: MaintenanceExpense[];
  saveProfile: (profile: VehicleProfile) => void;
  addMaintenanceExpense: (expense: MaintenanceExpense) => void;
  addFuelLog: (log: FuelLog) => void;
}

const initialState: PersistedState = {
  profile: null,
  trips: makeSeedTrips(),
  fuelLogs: makeSeedFuelLogs(),
  maintenanceReminders: makeSeedMaintenanceReminders(),
  maintenanceExpenses: makeSeedMaintenanceExpenses()
};

const AppContext = createContext<AppContextValue | undefined>(undefined);

export function AppProvider({ children }: PropsWithChildren) {
  const [isHydrating, setIsHydrating] = useState(true);
  const [profile, setProfile] = useState<VehicleProfile | null>(initialState.profile);
  const [trips] = useState<TripResult[]>(initialState.trips);
  const [fuelLogs, setFuelLogs] = useState<FuelLog[]>(initialState.fuelLogs);
  const [maintenanceReminders] = useState<MaintenanceReminder[]>(initialState.maintenanceReminders);
  const [maintenanceExpenses, setMaintenanceExpenses] = useState<MaintenanceExpense[]>(initialState.maintenanceExpenses);

  useEffect(() => {
    void (async () => {
      try {
        const raw = await AsyncStorage.getItem(STORAGE_KEY);
        if (raw) {
          const parsed = JSON.parse(raw) as PersistedState;
          setProfile(parsed.profile);
          setFuelLogs(parsed.fuelLogs ?? initialState.fuelLogs);
          setMaintenanceExpenses(parsed.maintenanceExpenses ?? initialState.maintenanceExpenses);
        }
      } finally {
        setIsHydrating(false);
      }
    })();
  }, []);

  useEffect(() => {
    if (isHydrating) {
      return;
    }

    const payload: PersistedState = {
      profile,
      trips,
      fuelLogs,
      maintenanceReminders,
      maintenanceExpenses
    };

    void AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
  }, [fuelLogs, isHydrating, maintenanceExpenses, maintenanceReminders, profile, trips]);

  const value = useMemo<AppContextValue>(
    () => ({
      isHydrating,
      profile,
      trips,
      fuelLogs,
      maintenanceReminders,
      maintenanceExpenses,
      saveProfile: (nextProfile) => setProfile(nextProfile),
      addMaintenanceExpense: (expense) => setMaintenanceExpenses((current) => [expense, ...current]),
      addFuelLog: (log) => setFuelLogs((current) => [log, ...current])
    }),
    [fuelLogs, isHydrating, maintenanceExpenses, maintenanceReminders, profile, trips]
  );

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useAppContext() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error("useAppContext must be used within AppProvider");
  }
  return context;
}
