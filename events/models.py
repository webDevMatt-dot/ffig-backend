from django.db import models

class Event(models.Model):
    title = models.CharField(max_length=200)
    location = models.CharField(max_length=100)
    date = models.DateField()
    image_url = models.URLField(default="https://images.unsplash.com/photo-1542744173-8e7e53415bb0") 
    is_featured = models.BooleanField(default=False)
    description = models.TextField(blank=True, default="Join us for an incredible networking experience.")
    ticket_url = models.URLField(blank=True, help_text="Link to Eventbrite or payment page")
    price_label = models.CharField(max_length=50, default="Free", help_text="e.g. '$50' or 'Starting at $99'")
    is_sold_out = models.BooleanField(default=False)

    def __str__(self):
        return self.title
