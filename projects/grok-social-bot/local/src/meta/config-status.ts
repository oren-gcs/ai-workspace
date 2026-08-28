import type { AppConfig } from "../config.js";

export interface MetaFieldStatus {
  key: string;
  label: string;
  set: boolean;
  required: boolean;
}

export interface MetaConfigStatus {
  whatsappProvider: string;
  fields: MetaFieldStatus[];
  readyForWebhook: boolean;
  readyForOutbound: boolean;
  readyForFacebook: boolean;
  missingRequired: string[];
}

function field(key: string, label: string, value: string, required: boolean): MetaFieldStatus {
  return { key, label, set: Boolean(value?.trim()), required };
}

/** Report Meta / WhatsApp / Facebook env completeness (no secret values). */
export function getMetaConfigStatus(config: AppConfig): MetaConfigStatus {
  const { meta, facebook } = config.social;
  const { whatsapp } = config;

  const fields: MetaFieldStatus[] = [
    field("META_APP_ID", "Meta App ID", meta.appId, whatsapp.provider === "meta"),
    field("META_APP_SECRET", "Meta App Secret", meta.appSecret, whatsapp.provider === "meta"),
    field(
      "WHATSAPP_ACCESS_TOKEN",
      "WhatsApp access token",
      whatsapp.meta.accessToken,
      whatsapp.provider === "meta"
    ),
    field(
      "WHATSAPP_PHONE_NUMBER_ID",
      "WhatsApp phone number ID",
      whatsapp.meta.phoneNumberId,
      whatsapp.provider === "meta"
    ),
    field(
      "WHATSAPP_BUSINESS_ACCOUNT_ID",
      "WhatsApp Business Account ID",
      whatsapp.meta.businessAccountId,
      false
    ),
    field("WEBHOOK_VERIFY_TOKEN", "Webhook verify token", whatsapp.meta.verifyToken, whatsapp.provider === "meta"),
    field("WHATSAPP_TEST_NUMBER", "WhatsApp test number (E.164)", whatsapp.testNumber, false),
    field("FACEBOOK_PAGE_ID", "Facebook Page ID", facebook.pageId, facebook.enabled),
    field(
      "FACEBOOK_PAGE_ACCESS_TOKEN",
      "Facebook Page access token",
      facebook.pageAccessToken,
      facebook.enabled
    ),
  ];

  const missingRequired = fields.filter((f) => f.required && !f.set).map((f) => f.key);

  const readyForWebhook =
    whatsapp.provider === "meta" &&
    Boolean(whatsapp.meta.verifyToken) &&
    Boolean(whatsapp.meta.phoneNumberId);

  const readyForOutbound =
    whatsapp.provider === "meta" &&
    Boolean(whatsapp.meta.accessToken && whatsapp.meta.phoneNumberId) &&
    whatsapp.allowOutbound &&
    Boolean(whatsapp.testNumber) &&
    !config.runner.dryRun;

  const readyForFacebook =
    facebook.enabled && Boolean(facebook.pageId && facebook.pageAccessToken && meta.appId);

  return {
    whatsappProvider: whatsapp.provider,
    fields,
    readyForWebhook,
    readyForOutbound,
    readyForFacebook,
    missingRequired,
  };
}

export function formatMetaConfigStatus(status: MetaConfigStatus): string[] {
  const lines: string[] = [];
  if (status.whatsappProvider !== "meta") {
    lines.push(`WhatsApp provider: ${status.whatsappProvider} (set WHATSAPP_PROVIDER=meta for Meta Cloud API)`);
    return lines;
  }

  lines.push("Meta WhatsApp Cloud API configuration:");
  for (const f of status.fields) {
    const mark = f.set ? "✓" : f.required ? "✗" : "○";
    const req = f.required ? " (required)" : "";
    lines.push(`  ${mark} ${f.key}${req}`);
  }

  if (status.missingRequired.length > 0) {
    lines.push(`Missing required: ${status.missingRequired.join(", ")}`);
  }

  lines.push(`Webhook ready: ${status.readyForWebhook ? "yes" : "no — set WEBHOOK_VERIFY_TOKEN + tunnel URL"}`);
  lines.push(
    `Outbound send ready: ${status.readyForOutbound ? "yes" : "no — need tokens + ALLOW_OUTBOUND_WHATSAPP + WHATSAPP_TEST_NUMBER + DRY_RUN=false"}`
  );
  lines.push(`Facebook Page connector: ${status.readyForFacebook ? "ready" : "stub — set ENABLE_FACEBOOK=true and page tokens"}`);

  return lines;
}
