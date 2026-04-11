from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from members.models import AdminAuditLog, BusinessProfile, ContentReport


class AdminAuditLogTests(APITestCase):
    def setUp(self):
        self.admin_user = User.objects.create_user(
            username='admin_test',
            email='admin@test.com',
            password='test12345',
            is_staff=True,
        )
        self.member_user = User.objects.create_user(
            username='member_test',
            email='member@test.com',
            password='test12345',
        )

        self.business_profile = BusinessProfile.objects.create(
            user=self.member_user,
            company_name='Acme Studio',
            description='Creative agency profile',
            status='PENDING',
        )

        self.client.force_authenticate(user=self.admin_user)

    def test_business_status_update_creates_audit_log(self):
        response = self.client.patch(
            reverse('admin-business-detail', kwargs={'pk': self.business_profile.id}),
            {'status': 'APPROVED'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(AdminAuditLog.objects.count(), 1)

        log = AdminAuditLog.objects.first()
        self.assertEqual(log.action_type, 'BUSINESS_STATUS')
        self.assertEqual(log.target_type, 'business_profile')
        self.assertEqual(log.target_id, str(self.business_profile.id))
        self.assertEqual(log.metadata.get('old_status'), 'PENDING')
        self.assertEqual(log.metadata.get('new_status'), 'APPROVED')

    def test_moderation_action_creates_audit_log(self):
        response = self.client.post(
            reverse('admin-moderation-action'),
            {
                'action': 'WARN',
                'target_user_id': self.member_user.id,
                'reason': 'Repeated policy warning',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(AdminAuditLog.objects.count(), 1)

        log = AdminAuditLog.objects.first()
        self.assertEqual(log.action_type, 'MODERATION_ACTION')
        self.assertEqual(log.target_type, 'user')
        self.assertEqual(log.target_id, str(self.member_user.id))
        self.assertEqual(log.reason, 'Repeated policy warning')
        self.assertEqual(log.metadata.get('action'), 'WARN')

    def test_admin_audit_logs_endpoint_lists_entries(self):
        AdminAuditLog.objects.create(
            actor=self.admin_user,
            action_type='REPORT_STATUS',
            target_type='content_report',
            target_id='44',
            target_label='USER:44',
            reason='Resolved after review',
            metadata={'old_status': 'OPEN', 'new_status': 'RESOLVED'},
        )

        response = self.client.get(reverse('admin-audit-logs'))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['action_type'], 'REPORT_STATUS')
        self.assertEqual(response.data[0]['target_id'], '44')

    def test_report_status_update_persists_and_logs_audit(self):
        report = ContentReport.objects.create(
            reporter=self.member_user,
            reported_item_type='USER',
            reported_item_id=str(self.member_user.id),
            reason='Suspicious behavior',
            status='OPEN',
        )

        response = self.client.patch(
            reverse('admin-report-detail', kwargs={'pk': report.id}),
            {'status': 'RESOLVED'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        report.refresh_from_db()
        self.assertEqual(report.status, 'RESOLVED')

        log = AdminAuditLog.objects.filter(
            action_type='REPORT_STATUS',
            target_id=str(report.id),
        ).first()
        self.assertIsNotNone(log)
        self.assertEqual(log.metadata.get('old_status'), 'OPEN')
        self.assertEqual(log.metadata.get('new_status'), 'RESOLVED')
