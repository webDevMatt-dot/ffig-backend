from django.core.management.base import BaseCommand
from chat.models import Conversation, Message

class Command(BaseCommand):
    help = 'Clears all messages from the public community chat'

    def handle(self, *args, **options):
        # Find the public conversation
        try:
            community_chat = Conversation.objects.filter(is_public=True).first()
            
            if not community_chat:
                self.stdout.write(self.style.WARNING('No public community chat found.'))
                return

            message_count = community_chat.messages.count()
            
            if message_count == 0:
                self.stdout.write(self.style.SUCCESS('Community chat is already empty.'))
                return

            # Confirm with the user if running interactively
            self.stdout.write(self.style.WARNING(f'You are about to delete {message_count} messages from the community chat.'))
            confirm = input("Type 'yes' to confirm: ")
            
            if confirm != 'yes':
                self.stdout.write(self.style.ERROR('Operation cancelled.'))
                return

            community_chat.messages.all().delete()
            self.stdout.write(self.style.SUCCESS(f'Successfully deleted {message_count} messages.'))

        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error occurred: {str(e)}'))
