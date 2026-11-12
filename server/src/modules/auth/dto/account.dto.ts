import {
  IsEmail,
  IsNotEmpty,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

/// 6-digit numeric code, used in verify-email and reset-password.
const CODE_RE = /^\d{6}$/;

export class VerifyEmailDto {
  @IsEmail()
  email: string;

  @IsString()
  @Matches(CODE_RE, { message: 'Код должен состоять из 6 цифр' })
  code: string;
}

export class ForgotPasswordDto {
  @IsEmail()
  email: string;
}

export class ResetPasswordDto {
  @IsEmail()
  email: string;

  @IsString()
  @Matches(CODE_RE, { message: 'Код должен состоять из 6 цифр' })
  code: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password: string;
}

export class ChangePasswordDto {
  @IsString()
  @IsNotEmpty()
  currentPassword: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  newPassword: string;
}

export class RefreshTokenDto {
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class LogoutDto {
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}