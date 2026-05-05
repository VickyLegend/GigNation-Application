"""
core/authentication.py
----------------------
Phase 1: Validates Supabase-issued JWTs so the Flutter app can send
         its existing tokens straight to Django without any changes.

Phase 2: Delete this file and switch DEFAULT_AUTHENTICATION_CLASSES
         to rest_framework_simplejwt only.
"""
import jwt
from django.conf import settings
from django.contrib.auth import get_user_model
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

User = get_user_model()


class SupabaseJWTAuthentication(BaseAuthentication):
    """
    Reads the Bearer token from the Authorization header,
    verifies it against SUPABASE_SECRET, then finds or lazily
    creates the matching Django user (keyed on supabase_uid).
    """

    def authenticate(self, request):
        header = request.headers.get('Authorization', '')
        if not header.startswith('Bearer '):
            return None                          # let next authenticator try

        token = header.split(' ', 1)[1]
        secret = settings.SUPABASE_SECRET
        if not secret:
            return None                          # Supabase auth not configured

        try:
            payload = jwt.decode(
                token,
                secret,
                algorithms=['HS256'],
                audience='authenticated',
            )
        except jwt.ExpiredSignatureError:
            raise AuthenticationFailed('Supabase token has expired.')
        except jwt.InvalidTokenError as e:
            raise AuthenticationFailed(f'Invalid Supabase token: {e}')

        supabase_uid = payload.get('sub')
        email        = payload.get('email', '')

        if not supabase_uid:
            raise AuthenticationFailed('Token missing subject claim.')

        # Lazily create a Django user so all FK relations work
        user, _ = User.objects.get_or_create(
            supabase_uid=supabase_uid,
            defaults={
                'email':    email,
                'username': email.split('@')[0] if email else supabase_uid[:8],
            },
        )

        # Keep email in sync if it changed in Supabase
        if email and user.email != email:
            user.email = email
            user.save(update_fields=['email'])

        return (user, token)

    def authenticate_header(self, request):
        return 'Bearer realm="gignation"'
