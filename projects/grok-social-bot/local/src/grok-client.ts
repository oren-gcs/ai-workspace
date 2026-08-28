import type { AppConfig } from "./config.js";

export interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

export interface GrokCompletionResult {
  text: string;
  model: string;
  usage?: { promptTokens?: number; completionTokens?: number };
}

export class GrokClient {
  constructor(private readonly config: AppConfig["xai"]) {}

  get isConfigured(): boolean {
    return Boolean(this.config.apiKey);
  }

  async chat(messages: ChatMessage[]): Promise<GrokCompletionResult> {
    if (!this.isConfigured) {
      throw new Error("XAI_API_KEY not set — cannot call Grok API");
    }

    const url = `${this.config.apiBase.replace(/\/$/, "")}/chat/completions`;
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.config.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: this.config.model,
        messages,
        temperature: 0.3,
      }),
    });

    if (!res.ok) {
      const body = await res.text();
      throw new Error(`Grok API ${res.status}: ${body.slice(0, 500)}`);
    }

    const data = (await res.json()) as {
      model?: string;
      choices?: Array<{ message?: { content?: string } }>;
      usage?: { prompt_tokens?: number; completion_tokens?: number };
    };

    const text = data.choices?.[0]?.message?.content ?? "";
    return {
      text,
      model: data.model ?? this.config.model,
      usage: {
        promptTokens: data.usage?.prompt_tokens,
        completionTokens: data.usage?.completion_tokens,
      },
    };
  }

  async summarizeDigest(mentions: string[], spotifyActivity: string[] = []): Promise<string> {
    if (mentions.length === 0 && spotifyActivity.length === 0) {
      return "No new social mentions or listening activity in this cycle.";
    }

    const sections: string[] = [];
    if (mentions.length > 0) {
      const bulletList = mentions.map((m, i) => `${i + 1}. ${m}`).join("\n");
      sections.push(`Social mentions:\n${bulletList}`);
    }
    if (spotifyActivity.length > 0) {
      const spotifyList = spotifyActivity.map((s, i) => `${i + 1}. ${s}`).join("\n");
      sections.push(`Spotify listening:\n${spotifyList}`);
    }

    const result = await this.chat([
      {
        role: "system",
        content:
          "You summarize social media mentions and Spotify listening activity for a WhatsApp digest. " +
          "Be concise, actionable, under 400 words. Flag sentiment and any urgent items. " +
          "When Spotify data is present, briefly note listening mood or patterns (e.g. focus music, new artists).",
      },
      {
        role: "user",
        content: `Summarize for today's digest:\n\n${sections.join("\n\n")}`,
      },
    ]);

    return result.text;
  }

  /** @deprecated Use summarizeDigest */
  async summarizeMentions(mentions: string[]): Promise<string> {
    return this.summarizeDigest(mentions);
  }
}
