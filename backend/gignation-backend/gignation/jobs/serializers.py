from rest_framework import serializers
from .models import Job, Application
from accounts.serializers import UserPublicSerializer


class JobSerializer(serializers.ModelSerializer):
    poster = UserPublicSerializer(source='user', read_only=True)
    tags   = serializers.ListField(
        child=serializers.CharField(max_length=50),
        default=list, required=False
    )

    class Meta:
        model  = Job
        fields = ['id', 'poster', 'title', 'company', 'location', 'budget',
                  'description', 'requirements', 'category', 'type', 'tags',
                  'status', 'applicants', 'created_at', 'updated_at']
        read_only_fields = ['id', 'poster', 'applicants', 'created_at', 'updated_at']

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)


class ApplicationSerializer(serializers.ModelSerializer):
    applicant  = UserPublicSerializer(source='user', read_only=True)
    job_title  = serializers.CharField(source='job.title', read_only=True)

    class Meta:
        model  = Application
        fields = ['id', 'job', 'job_title', 'applicant', 'cover_note',
                  'status', 'created_at', 'updated_at']
        read_only_fields = ['id', 'applicant', 'status', 'created_at', 'updated_at']

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)


class ApplicationStatusSerializer(serializers.ModelSerializer):
    """Used by job owners to accept/reject applications."""
    class Meta:
        model  = Application
        fields = ['status']
