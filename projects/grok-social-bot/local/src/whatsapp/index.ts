import type { AppConfig } from "../config.js";
import { getMetaConfigStatus } from "../meta/config-status.js";
import type { WhatsAppNotifier, WhatsAppSendResult } from "./types.js";

function canSend(config: AppConfig): { allowed: boolean; to: string; reason?: string } {
  if (!config.whatsapp.allowOutbound) {
    return { allowed: false, to: "", reason: "ALLOW_OUTBOUND_WHATSAPP is false" };
  }
  const to = config.whatsapp.testNumber || config.whatsapp.toNumber;
  if (!to) {
    return { allowed: false, to: "", reason: "WHATSAPP_TEST_NUMBER or WHATSAPP_TO_NUMBER required" };
  }
  return { allowed: true, to };
}

export class MetaWhatsAppNotifier implements WhatsAppNotifier {
  readonly provider = "meta";

  constructor(private readonly config: AppConfig) {}

  get isConfigured(): boolean {
    const m = this.config.whatsapp.meta;
    return Boolean(m.accessToken && m.phoneNumberId);
  }

  /** Human-readable missing fields (no secret values). */
  getMissingFields(): string[] {
    return getMetaConfigStatus(this.config).missingRequired;
  }

  async sendDigest(body: string): Promise<WhatsAppSendResult> {
    const gate = canSend(this.config);
    if (this.config.runner.dryRun) {
      const missing = this.getMissingFields();
      return {
        ok: true,
        provider: this.provider,
        skipped: true,
        reason:
          missing.length > 0
            ? `DRY_RUN (missing: ${missing.join(", ")})`
            : "DRY_RUN — would send when ALLOW_OUTBOUND_WHATSAPP=true",
      };
    }
    if (!gate.allowed) {
      return { ok: false, provider: this.provider, skipped: true, reason: gate.reason };
    }
    if (!this.isConfigured) {
      const missing = this.getMissingFields();
      return {
        ok: false,
        provider: this.provider,
        error: `Meta WhatsApp not configured — missing: ${missing.join(", ") || "WHATSAPP_ACCESS_TOKEN, WHATSAPP_PHONE_NUMBER_ID"} — see docs/CONFIG-META-WHATSAPP-FACEBOOK.md`,
      };
    }

    const { accessToken, phoneNumberId } = this.config.whatsapp.meta;
    const url = `https://graph.facebook.com/v21.0/${phoneNumberId}/messages`;
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to: gate.to.replace(/\D/g, ""),
        type: "text",
        text: { body: body.slice(0, 4096) },
      }),
    });

    if (!res.ok) {
      const errText = await res.text();
      return { ok: false, provider: this.provider, error: `Meta API ${res.status}: ${errText.slice(0, 300)}` };
    }

    const data = (await res.json()) as { messages?: Array<{ id: string }> };
    return {
      ok: true,
      provider: this.provider,
      messageId: data.messages?.[0]?.id,
    };
  }
}

export class TwilioWhatsAppNotifier implements WhatsAppNotifier {
  readonly provider = "twilio";

  constructor(private readonly config: AppConfig) {}

  get isConfigured(): boolean {
    const t = this.config.whatsapp.twilio;
    return Boolean(t.accountSid && t.authToken);
  }

  async sendDigest(body: string): Promise<WhatsAppSendResult> {
    const gate = canSend(this.config);
    if (this.config.runner.dryRun) {
      return { ok: true, provider: this.provider, skipped: true, reason: "DRY_RUN" };
    }
    if (!gate.allowed) {
      return { ok: false, provider: this.provider, skipped: true, reason: gate.reason };
    }
    if (!this.isConfigured) {
      return {
        ok: false,
        provider: this.provider,
        error: "Twilio not configured — see docs/WHATSAPP-SETUP.md",
      };
    }

    const { accountSid, authToken, from } = this.config.whatsapp.twilio;
    const to = gate.to.startsWith("whatsapp:") ? gate.to : `whatsapp:${gate.to}`;
    const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
    const auth = Buffer.from(`${accountSid}:${authToken}`).toString("base64");

    const params = new URLSearchParams({ From: from, To: to, Body: body.slice(0, 1600) });
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Basic ${auth}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params.toString(),
    });

    if (!res.ok) {
      const errText = await res.text();
      return { ok: false, provider: this.provider, error: `Twilio ${res.status}: ${errText.slice(0, 300)}` };
    }

    const data = (await res.json()) as { sid?: string };
    return { ok: true, provider: this.provider, messageId: data.sid };
  }
}

export class NoOpWhatsAppNotifier implements WhatsAppNotifier {
  readonly provider = "none";
  get isConfigured(): boolean {
    return false;
  }
  async sendDigest(_body: string): Promise<WhatsAppSendResult> {
    return {
      ok: true,
      provider: this.provider,
      skipped: true,
      reason: "WHATSAPP_PROVIDER=none",
    };
  }
}

export function createWhatsAppNotifier(config: AppConfig): WhatsAppNotifier {
  switch (config.whatsapp.provider) {
    case "meta":
      return new MetaWhatsAppNotifier(config);
    case "twilio":
      return new TwilioWhatsAppNotifier(config);
    default:
      return new NoOpWhatsAppNotifier();
  }
}
