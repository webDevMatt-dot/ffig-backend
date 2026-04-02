from rest_framework import serializers
from .models import Poll, PollOption, QuizQuestion, PollVote, QuizSubmission

class PollOptionSerializer(serializers.ModelSerializer):
    # Map 'vote_count' to 'votes' as expected by the frontend
    votes = serializers.IntegerField(source='vote_count', read_only=True)
    id = serializers.IntegerField(required=False) # Allow ID for updates

    class Meta:
        model = PollOption
        fields = ['id', 'label', 'votes']

class PollSerializer(serializers.ModelSerializer):
    options = PollOptionSerializer(many=True)
    selected_index = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = Poll
        fields = ['id', 'question', 'options', 'selected_index', 'expires_at', 'created_at']
        read_only_fields = ['created_at']

    def get_selected_index(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            vote = PollVote.objects.filter(user=request.user, poll=obj).first()
            if vote:
                # Find the index of the voted option in the options list (ordered by id)
                options = list(obj.options.all().order_by('id'))
                for i, opt in enumerate(options):
                    if opt.id == vote.option_id:
                        return i
        return None

    def create(self, validated_data):
        options_data = validated_data.pop('options')
        poll = Poll.objects.create(**validated_data)
        for opt_data in options_data:
            # Remove 'id' if present during creation (though shouldn't be)
            opt_data.pop('id', None)
            PollOption.objects.create(poll=poll, **opt_data)
        return poll

    def update(self, instance, validated_data):
        options_data = validated_data.pop('options', None)
        instance.question = validated_data.get('question', instance.question)
        instance.expires_at = validated_data.get('expires_at', instance.expires_at)
        instance.save()

        if options_data is not None:
            existing_options = {opt.id: opt for opt in instance.options.all()}
            
            for opt_data in options_data:
                opt_id = opt_data.get('id')
                if opt_id and opt_id in existing_options:
                    # Update existing option
                    opt = existing_options.pop(opt_id)
                    opt.label = opt_data.get('label', opt.label)
                    opt.save()
                else:
                    # Create new option
                    # Note: we ignore the ID if it's not in existing_options
                    opt_data.pop('id', None) 
                    PollOption.objects.create(poll=instance, **opt_data)
            
            # Delete options that were not in the update payload
            for opt in existing_options.values():
                opt.delete()

        return instance

class QuizQuestionSerializer(serializers.ModelSerializer):
    selected_index = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = QuizQuestion
        fields = [
            'id', 'prompt', 'options', 'correct_index', 
            'explanation', 'selected_index', 'expires_at', 'created_at'
        ]
        read_only_fields = ['created_at']

    def get_selected_index(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            submission = QuizSubmission.objects.filter(user=request.user, quiz_question=obj).first()
            if submission:
                return submission.selected_index
        return None
