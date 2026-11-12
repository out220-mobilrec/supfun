import { Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

export interface PushPayload {
  title: string;
  body: string | null;
  data: Record<string, string>;
}

@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  private readonly projectId = process.env.FCM_PROJECT_ID?.trim();
  private readonly clientEmail = process.env.FCM_CLIENT_EMAIL?.trim();
  private readonly privateKey = process.env.FCM_PRIVATE_KEY;

  private accessToken: string | null = null;
  private tokenExpiresAt = 0;

  constructor(private readonly jwtService: JwtService) {}

  get enabled(): boolean {
    return Boolean(this.projectId && this.clientEmail && this.privateKey);
  }

  async sendToTokens(
    tokens: string[],
    notification: PushPayload,
  ): Promise<void> {
    if (!this.enabled) {
      return;
    }
    for (const token of tokens) {
      try {
        const accessToken = await this.getAccessToken();
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${this.projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token,
                notification: {
                  title: notification.title,
                  body: notification.body ?? '',
                },
                data: notification.data,
              },
            }),
          },
        );
        if (!res.ok) {
          const text = await res.text();
          this.logger.warn(`FCM send failed (${res.status}): ${text}`);
          if (res.status === 404 || res.status === 400) {
            this.logger.warn(`FCM token invalid: ${token.slice(0, 24)}...`);
          }
        }
      } catch (error) {
        this.logger.warn(`FCM push error: ${(error as Error).message}`);
      }
    }
  }

  private async getAccessToken(): Promise<string> {
    if (this.accessToken && Date.now() < this.tokenExpiresAt - 60_000) {
      return this.accessToken;
    }
    const iat = Math.floor(Date.now() / 1000);
    const assertion = await this.jwtService.signAsync(
      {
        iss: this.clientEmail,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat,
        exp: iat + 3599,
      },
      {
        algorithm: 'RS256',
        privateKey: this.privateKey,
      },
    );
    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }).toString(),
    });
    const json = (await res.json()) as {
      access_token?: string;
      expires_in?: number;
      error?: string;
    };
    if (!res.ok || !json.access_token) {
      throw new Error(`FCM token exchange failed: ${json.error ?? res.status}`);
    }
    this.accessToken = json.access_token;
    this.tokenExpiresAt = Date.now() + (json.expires_in ?? 3600) * 1000;
    return this.accessToken;
  }
}