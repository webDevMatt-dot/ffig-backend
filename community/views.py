from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from django.utils import timezone
from django.db import transaction
from .models import Poll, PollOption, QuizQuestion, PollVote, QuizSubmission
from .serializers import PollSerializer, QuizQuestionSerializer

class PollViewSet(viewsets.ModelViewSet): # Changed from ReadOnlyModelViewSet
    """
    ViewSet for listing active polls, casting votes, and management (Admin).
    """
    permission_classes = [IsAuthenticated]
    serializer_class = PollSerializer

    def get_queryset(self):
        # Admins/Staff should see all polls for management
        if self.request.user.is_staff:
            return Poll.objects.all().order_by('-created_at')
            
        # Regular users only see active ones
        return Poll.objects.filter(expires_at__gt=timezone.now()).order_by('-created_at')

    def get_permissions(self):
        """
        Custom permissions:
        - List/Retrieve: IsAuthenticated
        - Vote (action): IsAuthenticated
        - Create/Update/Delete (standard): IsAdminUser
        """
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsAdminUser()]
        return super().get_permissions()

    @action(detail=True, methods=['post'])
    def vote(self, request, pk=None):
        poll = self.get_object()
        
        # Check if the poll has expired
        if not poll.is_active:
             return Response({'error': 'This poll has expired.'}, status=status.HTTP_400_BAD_REQUEST)
             
        option_id = request.data.get('option_id')
        if not option_id:
            return Response({'error': 'option_id is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            # Ensure the option belongs to the correct poll
            option = PollOption.objects.get(id=option_id, poll=poll)
        except PollOption.DoesNotExist:
            return Response({'error': 'Invalid option_id for this poll'}, status=status.HTTP_400_BAD_REQUEST)
        
        with transaction.atomic():
            # Check for existing vote to prevent double-voting (or allow switching)
            existing_vote = PollVote.objects.filter(user=request.user, poll=poll).first()
            if existing_vote:
                if existing_vote.option_id == int(option_id):
                    return Response({'message': 'Vote already recorded for this option.'}, status=status.HTTP_200_OK)
                
                # If they want to change their vote, we must decrement the previous option's counter
                previous_option = existing_vote.option
                previous_option.vote_count = max(0, previous_option.vote_count - 1)
                previous_option.save()
                
                existing_vote.option = option
                existing_vote.save()
            else:
                # Create the vote tracking entry
                PollVote.objects.create(user=request.user, poll=poll, option=option)
            
            # Increment the new option's counter
            option.vote_count += 1
            option.save()
            
        return Response({'message': 'Vote recorded successfully'}, status=status.HTTP_200_OK)


class QuizViewSet(viewsets.ModelViewSet): # Changed from ReadOnlyModelViewSet
    """
    ViewSet for listing active quizzes, submitting answers, and management (Admin).
    """
    permission_classes = [IsAuthenticated]
    serializer_class = QuizQuestionSerializer

    def get_queryset(self):
        # Admins/Staff should see all quiz questions for management
        if self.request.user.is_staff:
            return QuizQuestion.objects.all().order_by('-created_at')
            
        # Regular users only see active ones
        return QuizQuestion.objects.filter(expires_at__gt=timezone.now()).order_by('-created_at')

    def get_permissions(self):
        """
        Custom permissions:
        - List/Retrieve/Submit: IsAuthenticated
        - Create/Update/Delete (standard): IsAdminUser
        """
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsAdminUser()]
        return super().get_permissions()

    @action(detail=True, methods=['post'])
    def submit(self, request, pk=None):
        quiz = self.get_object()
        
        # Check if the quiz has expired
        if not quiz.is_active:
             return Response({'error': 'This quiz has expired.'}, status=status.HTTP_400_BAD_REQUEST)
             
        selected_index = request.data.get('selected_index')
        if selected_index is None:
            return Response({'error': 'selected_index is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Quizzes should be one-time only as per user requirements
        if QuizSubmission.objects.filter(user=request.user, quiz_question=quiz).exists():
            return Response({'error': 'You have already submitted an answer for this quiz.'}, status=status.HTTP_400_BAD_REQUEST)
        
        QuizSubmission.objects.create(
            user=request.user,
            quiz_question=quiz,
            selected_index=int(selected_index)
        )
        
        return Response({'message': 'Submission successful'}, status=status.HTTP_200_OK)
