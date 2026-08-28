export interface SocialMention {
  id: string;
  platform: string;
  author: string;
  text: string;
  url?: string;
  createdAt: Date;
}

export interface SocialConnector {
  readonly platform: string;
  readonly isConfigured: boolean;
  fetchRecentMentions(since: Date): Promise<SocialMention[]>;
}

export function formatMention(m: SocialMention): string {
  const link = m.url ? ` ${m.url}` : "";
  return `[${m.platform}] @${m.author}: ${m.text}${link}`;
}
