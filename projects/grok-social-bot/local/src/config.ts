import "dotenv/config";

export interface AppConfig {
  xai: {
    apiKey: string;
    apiBase: string;
    model: string;
  };
  server: {
    host: string;
    port: number;
    webhookPath: string;
    webhookSecret: string;
    publicWebhookBaseUrl: string;
  };
  runner: {
    pollIntervalMs: number;
    dryRun: boolean;
  };
  whatsapp: {
    provider: "meta" | "twilio" | "none";
    toNumber: string;
    testNumber: string;
    allowOutbound: boolean;
    meta: {
      token: string;
      phoneNumberId: string;
      businessAccountId: string;
      verifyToken: string;
      appSecret: string;
    };
    twilio: {
      accountSid: string;
      authToken: string;
      from: string;
    };
  };
  social: {
    twitter: { enabled: boolean; bearerToken: string };
    linkedin: { enabled: boolean; accessToken: string };
    instagram: { enabled: boolean; accessToken: string };
  };
}

function envBool(key: string, fallback = false): boolean {
  const v = process.env[key];
  if (v === undefined || v === "") return fallback;
  return v === "1" || v.toLowerCase() === "true";
}

function envInt(key: string, fallback: number): number {
  const v = process.env[key];
  if (!v) return fallback;
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : fallback;
}

export function loadConfig(): AppConfig {
  const dryRunArg = process.argv.includes("--dry-run");
  const provider = (process.env.WHATSAPP_PROVIDER ?? "none").toLowerCase();

  return {
    xai: {
      apiKey: process.env.XAI_API_KEY ?? "",
      apiBase: process.env.XAI_API_BASE ?? "https://api.x.ai/v1",
      model: process.env.XAI_MODEL ?? "grok-3",
    },
    server: {
      host: process.env.BOT_HOST ?? "127.0.0.1",
      port: envInt("BOT_PORT", 3847),
      webhookPath: process.env.WEBHOOK_PATH ?? "/webhook/whatsapp",
      webhookSecret: process.env.WEBHOOK_SECRET ?? "",
      publicWebhookBaseUrl: process.env.PUBLIC_WEBHOOK_BASE_URL ?? "",
    },
    runner: {
      pollIntervalMs: envInt("POLL_INTERVAL_MS", 300_000),
      dryRun: dryRunArg || envBool("DRY_RUN", true),
    },
    whatsapp: {
      provider: provider === "meta" || provider === "twilio" ? provider : "none",
      toNumber: process.env.WHATSAPP_TO_NUMBER ?? "",
      testNumber: process.env.WHATSAPP_TEST_NUMBER ?? "",
      allowOutbound: envBool("ALLOW_OUTBOUND_WHATSAPP", false),
      meta: {
        token: process.env.META_WHATSAPP_TOKEN ?? "",
        phoneNumberId: process.env.META_WHATSAPP_PHONE_NUMBER_ID ?? "",
        businessAccountId: process.env.META_WHATSAPP_BUSINESS_ACCOUNT_ID ?? "",
        verifyToken: process.env.META_WEBHOOK_VERIFY_TOKEN ?? "",
        appSecret: process.env.META_APP_SECRET ?? "",
      },
      twilio: {
        accountSid: process.env.TWILIO_ACCOUNT_SID ?? "",
        authToken: process.env.TWILIO_AUTH_TOKEN ?? "",
        from: process.env.TWILIO_WHATSAPP_FROM ?? "whatsapp:+14155238886",
      },
    },
    social: {
      twitter: {
        enabled: envBool("ENABLE_TWITTER", false),
        bearerToken: process.env.TWITTER_BEARER_TOKEN ?? "",
      },
      linkedin: {
        enabled: envBool("ENABLE_LINKEDIN", false),
        accessToken: process.env.LINKEDIN_ACCESS_TOKEN ?? "",
      },
      instagram: {
        enabled: envBool("ENABLE_INSTAGRAM", false),
        accessToken: process.env.INSTAGRAM_ACCESS_TOKEN ?? "",
      },
    },
  };
}

export function validateConfig(config: AppConfig): string[] {
  const issues: string[] = [];

  if (!config.xai.apiKey) {
    issues.push("XAI_API_KEY missing — Grok summarization disabled");
  }

  if (config.whatsapp.provider === "none") {
    issues.push("WHATSAPP_PROVIDER=none — notifications stub only");
  } else if (config.whatsapp.provider === "meta") {
    if (!config.whatsapp.meta.token || !config.whatsapp.meta.phoneNumberId) {
      issues.push("Meta WhatsApp: set META_WHATSAPP_TOKEN and META_WHATSAPP_PHONE_NUMBER_ID");
    }
  } else if (config.whatsapp.provider === "twilio") {
    if (!config.whatsapp.twilio.accountSid || !config.whatsapp.twilio.authToken) {
      issues.push("Twilio: set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN");
    }
  }

  if (!config.runner.dryRun && config.whatsapp.allowOutbound) {
    if (!config.whatsapp.testNumber) {
      issues.push("ALLOW_OUTBOUND_WHATSAPP requires WHATSAPP_TEST_NUMBER");
    }
  }

  const anySocial =
    config.social.twitter.enabled ||
    config.social.linkedin.enabled ||
    config.social.instagram.enabled;
  if (!anySocial) {
    issues.push("No social platforms enabled — set ENABLE_TWITTER/LINKEDIN/INSTAGRAM after OAuth");
  }

  return issues;
}
