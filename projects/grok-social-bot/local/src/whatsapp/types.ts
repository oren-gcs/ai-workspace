export interface WhatsAppSendResult {
  ok: boolean;
  provider: string;
  messageId?: string;
  error?: string;
  skipped?: boolean;
  reason?: string;
}

export interface WhatsAppNotifier {
  readonly provider: string;
  readonly isConfigured: boolean;
  sendDigest(body: string): Promise<WhatsAppSendResult>;
}
