import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, Platform, Pressable, StyleSheet, Text, TextInput, View } from "react-native";
import { AppCard } from "../../components/AppCard";
import { Screen } from "../../components/Screen";
import { StructuredCard } from "../../components/StructuredCard";
import { CopilotQueryResponse, DailyBrief, VapiRuntimeConfig, VoiceSummaryResponse } from "../../models/agent";
import { CopilotClient } from "../../services/backend/CopilotClient";
import { VapiConfigClient } from "../../services/backend/VapiConfigClient";
import { VoiceAgentClient } from "../../services/backend/VoiceAgentClient";
import { VapiWebClient } from "../../services/vapi/VapiWebClient";
import { useAppContext } from "../../state/AppContext";
import { palette, radius, spacing } from "../../theme";

const copilotClient = new CopilotClient();
const voiceClient = new VoiceAgentClient();
const vapiConfigClient = new VapiConfigClient();

export function CopilotHomeScreen() {
  const { profile } = useAppContext();
  const [dailyBrief, setDailyBrief] = useState<DailyBrief | null>(null);
  const [queryText, setQueryText] = useState("Why did my fuel outlook change this week?");
  const [queryResult, setQueryResult] = useState<CopilotQueryResponse | null>(null);
  const [voiceSummary, setVoiceSummary] = useState<VoiceSummaryResponse | null>(null);
  const [loadingBrief, setLoadingBrief] = useState(false);
  const [loadingQuery, setLoadingQuery] = useState(false);
  const [loadingVoice, setLoadingVoice] = useState(false);
  const [loadingVapi, setLoadingVapi] = useState(false);
  const [vapiConfig, setVapiConfig] = useState<VapiRuntimeConfig | null>(null);
  const [liveVoiceActive, setLiveVoiceActive] = useState(false);
  const [liveVoiceStatus, setLiveVoiceStatus] = useState<string | null>(null);
  const [lastTranscript, setLastTranscript] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [vapiWebClient] = useState(() => new VapiWebClient());

  const loadDailyBrief = useCallback(async () => {
    setLoadingBrief(true);
    setError(null);
    try {
      const response = await copilotClient.getDailyBrief();
      setDailyBrief(response);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Could not load the daily brief.");
    } finally {
      setLoadingBrief(false);
    }
  }, []);

  const loadVapiConfig = useCallback(async () => {
    setLoadingVapi(true);
    try {
      const response = await vapiConfigClient.getConfig();
      setVapiConfig(response);
      setLiveVoiceStatus(response.message);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Could not load Vapi configuration.");
    } finally {
      setLoadingVapi(false);
    }
  }, []);

  useEffect(() => {
    void loadDailyBrief();
    void loadVapiConfig();

    return () => {
      void vapiWebClient.stop();
    };
  }, [loadDailyBrief, loadVapiConfig, vapiWebClient]);

  const handleAsk = async () => {
    if (!profile || !queryText.trim()) {
      return;
    }

    setLoadingQuery(true);
    setError(null);
    try {
      const response = await copilotClient.query({
        userId: profile.id,
        query: queryText.trim()
      });
      setQueryResult(response);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Could not run the copilot query.");
    } finally {
      setLoadingQuery(false);
    }
  };

  const handleVoiceSummary = async () => {
    if (!profile || !queryText.trim()) {
      return;
    }

    setLoadingVoice(true);
    setError(null);
    try {
      const response = await voiceClient.summarize({
        userId: profile.id,
        context: "copilot",
        transcript: queryText.trim()
      });
      setVoiceSummary(response);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Could not create the voice summary.");
    } finally {
      setLoadingVoice(false);
    }
  };

  const handleStartLiveVoice = async () => {
    if (!vapiConfig) {
      return;
    }

    setError(null);
    setLastTranscript(null);
    setLiveVoiceStatus("Connecting to ACM Voice Copilot...");

    try {
      await vapiWebClient.start(vapiConfig, {
        onCallStart: () => setLiveVoiceActive(true),
        onCallEnd: () => setLiveVoiceActive(false),
        onStatus: (status) => setLiveVoiceStatus(status),
        onTranscript: (transcript) => setLastTranscript(transcript),
        onError: (message) => {
          setLiveVoiceActive(false);
          setError(message);
        }
      });
    } catch (nextError) {
      setLiveVoiceActive(false);
      setError(nextError instanceof Error ? nextError.message : "Could not start live Vapi voice.");
    }
  };

  const handleStopLiveVoice = async () => {
    setError(null);
    try {
      await vapiWebClient.stop();
      setLiveVoiceActive(false);
      setLiveVoiceStatus("Live voice stopped.");
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Could not stop live Vapi voice.");
    }
  };

  return (
    <Screen>
      <AppCard title="Copilot Daily Brief" subtitle="This tab merges Fuel Agent and Maintenance Agent context through backend memory.">
        {loadingBrief ? <ActivityIndicator color={palette.primary} /> : null}
        {dailyBrief ? (
          <>
            <Text style={styles.headline}>{dailyBrief.headline}</Text>
            {dailyBrief.cards.map((card) => (
              <StructuredCard key={card.id} card={card} />
            ))}
          </>
        ) : null}
        <Pressable style={styles.refreshButton} onPress={() => void loadDailyBrief()}>
          <Text style={styles.refreshButtonText}>Refresh Daily Brief</Text>
        </Pressable>
      </AppCard>

      <AppCard title="Ask Copilot" subtitle="Typed questions go to POST /copilot/query. Voice summaries go to POST /voice/summary.">
        <TextInput
          value={queryText}
          onChangeText={setQueryText}
          placeholder="Ask about fuel, maintenance, or route behavior..."
          style={[styles.input, styles.multiline]}
          multiline
        />
        <View style={styles.row}>
          <Pressable style={styles.primaryButton} onPress={() => void handleAsk()}>
            <Text style={styles.buttonText}>{loadingQuery ? "Thinking..." : "Ask Copilot"}</Text>
          </Pressable>
          <Pressable style={styles.secondaryButton} onPress={() => void handleVoiceSummary()}>
            <Text style={styles.secondaryButtonText}>{loadingVoice ? "Building..." : "Voice Summary"}</Text>
          </Pressable>
        </View>

        {error ? <Text style={styles.errorText}>{error}</Text> : null}

        {queryResult ? (
          <View style={styles.resultGroup}>
            <Text style={styles.headline}>{queryResult.answer}</Text>
            {queryResult.cards.map((card) => (
              <StructuredCard key={card.id} card={card} />
            ))}
          </View>
        ) : null}

        {voiceSummary ? (
          <View style={styles.resultGroup}>
            <Text style={styles.headline}>{voiceSummary.summary}</Text>
            {voiceSummary.cards.map((card) => (
              <StructuredCard key={card.id} card={card} />
            ))}
          </View>
        ) : null}
      </AppCard>

      <AppCard title="Live Voice Copilot" subtitle="This connects the ACM Voice Copilot squad through Vapi when browser voice is available.">
        {loadingVapi ? <ActivityIndicator color={palette.primary} /> : null}
        {vapiConfig ? <Text style={styles.bodyText}>{vapiConfig.message}</Text> : null}
        {liveVoiceStatus ? <Text style={styles.statusText}>{liveVoiceStatus}</Text> : null}
        {vapiConfig?.squadName ? <Text style={styles.metaText}>Squad: {vapiConfig.squadName}</Text> : null}
        {lastTranscript ? <Text style={styles.metaText}>{lastTranscript}</Text> : null}

        <View style={styles.row}>
          <Pressable
            style={[styles.primaryButton, (!vapiConfig?.webSdkReady || liveVoiceActive) && styles.disabledButton]}
            disabled={!vapiConfig?.webSdkReady || liveVoiceActive}
            onPress={() => void handleStartLiveVoice()}
          >
            <Text style={styles.buttonText}>{liveVoiceActive ? "Live Voice Active" : "Start Live Voice"}</Text>
          </Pressable>
          <Pressable
            style={[styles.secondaryButton, !liveVoiceActive && styles.disabledButton]}
            disabled={!liveVoiceActive}
            onPress={() => void handleStopLiveVoice()}
          >
            <Text style={styles.secondaryButtonText}>Stop Voice</Text>
          </Pressable>
        </View>

        <Text style={styles.metaText}>
          {Platform.OS === "web"
            ? "Expo Web can start the live call directly. On iOS and Android, keep using the backend voice summary path until a native Vapi SDK is added."
            : "This build is running on native. Live browser voice is prepared on the backend, and the existing voice summary call remains your fallback here."}
        </Text>
      </AppCard>
    </Screen>
  );
}

const styles = StyleSheet.create({
  headline: {
    color: palette.text,
    fontSize: 18,
    fontWeight: "800",
    lineHeight: 24
  },
  bodyText: {
    color: palette.text,
    lineHeight: 20
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
    minHeight: 96,
    textAlignVertical: "top"
  },
  row: {
    flexDirection: "row",
    gap: spacing.sm
  },
  primaryButton: {
    flex: 1,
    backgroundColor: palette.primary,
    borderRadius: radius.sm,
    paddingVertical: 12,
    alignItems: "center"
  },
  secondaryButton: {
    flex: 1,
    backgroundColor: palette.surfaceStrong,
    borderRadius: radius.sm,
    paddingVertical: 12,
    alignItems: "center",
    borderWidth: 1,
    borderColor: palette.border
  },
  refreshButton: {
    marginTop: spacing.sm,
    backgroundColor: palette.primarySoft,
    borderRadius: radius.sm,
    paddingVertical: 12,
    alignItems: "center"
  },
  buttonText: {
    color: "#fff",
    fontWeight: "800"
  },
  refreshButtonText: {
    color: palette.primary,
    fontWeight: "800"
  },
  secondaryButtonText: {
    color: palette.text,
    fontWeight: "800"
  },
  disabledButton: {
    opacity: 0.5
  },
  resultGroup: {
    gap: spacing.sm
  },
  statusText: {
    color: palette.primary,
    fontWeight: "700"
  },
  metaText: {
    color: palette.mutedText,
    lineHeight: 20
  },
  errorText: {
    color: palette.danger
  }
});
