// screens/verification_screen.dart
import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../services/app_service.dart';

class VerificationScreen extends StatefulWidget {
  final ItemModel item;

  const VerificationScreen({super.key, required this.item});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _answerControllers = [];
  final AppService _appService = AppService();
  bool _isLoading = false;
  bool _isVerified = false;
  double _score = 0.0;
  int _attemptCount = 0;

  @override
  void initState() {
    super.initState();
    _answerControllers.addAll(
      List.generate(
        widget.item.securityQuestions.length,
            (index) => TextEditingController(),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _canAttemptVerification() async {
    final currentUserId = _appService.currentUserId;
    if (currentUserId == null) return false;
    return await _appService.canUserAttemptVerification(widget.item.id, currentUserId);
  }

  Future<void> _submitVerification() async {
    if (_isLoading) return;

    final currentUserId = _appService.currentUserId ?? 'user_guest';

    final canAttempt = await _canAttemptVerification();
    if (!canAttempt || _attemptCount >= 3) {
      _showError('You have used all 3 verification attempts for this item.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      int correctCount = 0;
      final answers = <String, String>{};

      for (int i = 0; i < widget.item.securityQuestions.length; i++) {
        final userAnswer = _answerControllers[i].text.trim().toLowerCase();
        final correctAnswer = widget.item.securityQuestions[i]['answer']?.toLowerCase() ?? '';

        answers['question${i+1}'] = userAnswer;

        if (userAnswer == correctAnswer) {
          correctCount++;
        }
      }

      final score = widget.item.securityQuestions.isNotEmpty
          ? (correctCount / widget.item.securityQuestions.length) * 100
          : 100.0;

      _attemptCount++;

      await _appService.saveVerificationAttempt(
        itemId: widget.item.id,
        userId: currentUserId,
        score: score,
        status: score >= 40 ? 'verified' : 'failed',
        answers: answers,
      );

      if (score >= 40) {
        final updatedItem = ItemModel(
          id: widget.item.id,
          title: widget.item.title,
          description: widget.item.description,
          location: widget.item.location,
          category: widget.item.category,
          isLost: widget.item.isLost,
          date: widget.item.date,
          reportDate: widget.item.reportDate,
          uploader: widget.item.uploader,
          uploaderId: widget.item.uploaderId,
          imageUrl: widget.item.imageUrl,
          createdAt: widget.item.createdAt,
          updatedAt: DateTime.now(),
          securityQuestions: widget.item.securityQuestions,
          requiresVerification: widget.item.requiresVerification,
          isClaimed: widget.item.isClaimed,
          verifiedClaimerId: currentUserId,
          verificationDate: DateTime.now(),
        );

        await _appService.updateItem(updatedItem);
        await _sendVerificationNotification(score);

        setState(() {
          _isVerified = true;
          _score = score;
        });

        _showSuccess('Verification successful! You can now contact the uploader.');

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } else {
        setState(() {
          _score = score;
        });

        final remainingAttempts = 3 - _attemptCount;
        _showError('Verification failed. You scored ${score.toStringAsFixed(1)}%. '
            'Need at least 40% to pass. '
            'Remaining attempts: $remainingAttempts');
      }
    } catch (e) {
      _showError('Error during verification: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendVerificationNotification(double score) async {
    try {
      await _appService.sendVerificationNotification(
        itemId: widget.item.id,
        itemTitle: widget.item.title,
        verifierName: _appService.currentUserEmail ?? 'User',
        verifierId: _appService.currentUserId ?? 'guest',
        uploaderId: widget.item.uploaderId,
        score: score,
      );
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Verification'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified_outlined, color: Colors.blue),
                        SizedBox(width: 10),
                        Text(
                          'Verify Ownership',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Answer these questions to prove you\'re the rightful owner of '
                          '"${widget.item.title}".',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Need ≥40% correct answers to verify | Max 3 attempts',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Questions List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.item.securityQuestions.length,
              itemBuilder: (context, index) {
                return _buildQuestionCard(index);
              },
            ),

            const SizedBox(height: 30),

            // Progress/Score Display
            if (_score > 0)
              Card(
                color: _score >= 40 ? Colors.green.shade50 : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Your Score: ${_score.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _score >= 40 ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _score / 100,
                        backgroundColor: Colors.grey.shade300,
                        color: _score >= 40 ? Colors.green : Colors.orange,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _score >= 40
                            ? '✅ Congratulations! You have verified ownership.'
                            : '⚠️ Need at least 40% to verify.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _score >= 40 ? Colors.green.shade800 : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 30),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _isVerified ? null : _submitVerification,
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Icon(_isVerified ? Icons.verified : Icons.send),
                label: _isLoading
                    ? const Text('Verifying...')
                    : Text(
                  _isVerified ? 'Verified Successfully' : 'Submit Verification',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isVerified ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Security Information',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• All answers are case-insensitive\n'
                          '• Maximum 3 attempts total for this item\n'
                          '• You need at least 40% correct answers\n'
                          '• After verification, you can contact the uploader\n'
                          '• Uploader will be notified of your verification',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${index + 1} of ${widget.item.securityQuestions.length}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.item.securityQuestions[index]['question'] ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _answerControllers[index],
              decoration: InputDecoration(
                labelText: 'Your Answer',
                hintText: 'Type your answer here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              enabled: !_isVerified && !_isLoading,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}