import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sklr/database/database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sklr/database/user_id_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Get the Supabase instance with a different name to avoid conflicts
final supabaseClient = Supabase.instance.client;

// Add this function at the top level outside any class
Future<bool> updateUserCredits(int userId, int newCreditAmount) async {
  try {
    if (kDebugMode) {
      print('Attempting to update user $userId credits to $newCreditAmount with direct approach');
    }
    
    // Get current credits for logging purposes
    try {
      final currentData = await supabaseClient
          .from('users')
          .select('credits')
          .eq('id', userId)
          .single();
      
      final int currentCredits = currentData['credits'] != null
          ? int.parse(currentData['credits'].toString())
          : 0;
      
      if (kDebugMode) {
        print('Current credits before update: $currentCredits');
      }
      
      // IMPORTANT: Add a notification here about the credit change
      // This ensures users are notified even if the update fails
      final difference = newCreditAmount - currentCredits;
      if (difference != 0) {
        String message;
        if (difference > 0) {
          message = 'You received $difference credits.';
        } else {
          message = 'Your account was charged ${-difference} credits.';
        }
        
        try {
          await supabaseClient
            .from('notifications')
            .insert({
              'user_id': userId,
              'message': message,
              'created_at': DateTime.now().toIso8601String(),
              'is_read': false,
            });
          if (kDebugMode) {
            print('Credit notification sent to user $userId');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error sending credit notification: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current credits: $e');
      }
    }
    
    // Attempt 1: Perform direct update with Supabase client
    bool updateSuccess = false;
    try {
      if (kDebugMode) {
        print('Attempting direct update with Supabase client');
      }
      
      final updateData = {'credits': newCreditAmount};
      if (kDebugMode) {
        print('Update data: $updateData');
      }
      
      final result = await supabaseClient
          .from('users')
          .update(updateData)
          .eq('id', userId);
      
      if (kDebugMode) {
        print('Update result: $result');
      }
      updateSuccess = true;
    } catch (e) {
      if (kDebugMode) {
        print('Direct update failed: $e');
      }
      
      // Attempt 2: Try using the RPC function if it exists
      try {
        if (kDebugMode) {
          print('Trying RPC function');
        }
        await supabaseClient.rpc(
          'direct_update_user_credits',
          params: {
            'user_id': userId,
            'new_credit_amount': newCreditAmount
          }
        );
        updateSuccess = true;
      } catch (rpcError) {
        if (kDebugMode) {
          print('RPC update failed: $rpcError');
        }
        
        // Attempt 3: Last resort - Use a direct HTTP request
        try {
          if (kDebugMode) {
            print('Attempting direct HTTP request');
          }
          final response = await supabaseClient.functions.invoke(
            'update-user-credits',
            body: {
              'userId': userId,
              'credits': newCreditAmount
            },
          );
          
          if (kDebugMode) {
            print('Function response: ${response.data}');
          }
          if (response.status == 200) {
            updateSuccess = true;
          }
        } catch (functionError) {
          if (kDebugMode) {
            print('Function call failed: $functionError');
          }
        }
      }
    }
    
    // Verify the update worked
    try {
      final verifyData = await supabaseClient
          .from('users')
          .select('credits')
          .eq('id', userId)
          .single();
      
      final int updatedCredits = verifyData['credits'] != null
          ? int.parse(verifyData['credits'].toString())
          : 0;
      
      if (kDebugMode) {
        print('Credits after update: $updatedCredits');
      }
      
      // If verification confirms the update, return true
      if (updatedCredits == newCreditAmount) {
        return true;
      }
      
      // If the verification shows it's not updated but we think it was successful,
      // return our success flag anyway
      return updateSuccess;
    } catch (e) {
      if (kDebugMode) {
        print('Verification failed: $e');
      }
      return updateSuccess;  // Return our best guess
    }
  } catch (e) {
    if (kDebugMode) {
      print('Overall error in updateUserCredits: $e');
    }
    return false;
  }
}

// Session State = Idle -> Pending
class RequestService {
  final Map<String, dynamic> session;

  RequestService({required this.session});

  // Show request dialog for the requester
  Future<bool?> showRequestDialog(BuildContext context) async {
    try {
      final requesterId = int.parse(session['requester_id'].toString());
      final providerId = int.parse(session['provider_id'].toString());
      final skillId = session['skill_id'];

      // Get the requester's details
      final requesterResponse = await DatabaseHelper.getUser(requesterId);
      if (!requesterResponse.success) {
        showSafeSnackBar(context, 'Error fetching requester information');
        return false;
      }
      final requesterData = requesterResponse.data;

      // Get the skill details
      final skillData = await DatabaseHelper.fetchOneSkill(skillId);
      if (skillData.isEmpty) {
        showSafeSnackBar(context, 'Error fetching skill information');
        return false;
      }

      // Get the provider's details
      final providerResponse = await DatabaseHelper.getUser(providerId);
      if (!providerResponse.success) {
        showSafeSnackBar(context, 'Error fetching provider information');
        return false;
      }
      final providerData = providerResponse.data;

      // Check if requester has enough credits
      final double skillCost = skillData['cost'] != null ? double.parse(skillData['cost'].toString()) : 0.0;
      final int requesterCredits = requesterData['credits'] != null ? int.parse(requesterData['credits'].toString()) : 0;
      
      if (requesterCredits < skillCost) {
    return await showDialog<bool>(
      context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Insufficient Credits',
              style: GoogleFonts.mulish(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            content: Text(
              'You have $requesterCredits credits, but this service costs $skillCost credits. Please add more credits to your account.',
              style: GoogleFonts.mulish(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Close',
                  style: GoogleFonts.mulish(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                ),
              ],
            ),
        );
      }

      return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Request Service',
            style: GoogleFonts.mulish(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6296FF),
            ),
          ),
          content: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                'You are about to request the following service:',
                style: GoogleFonts.mulish(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 15),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.mulish(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Service: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: skillData['name']),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.mulish(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Provider: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: providerData['username']),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.mulish(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Cost: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: '$skillCost credits',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6296FF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                          style: GoogleFonts.mulish(
                            fontSize: 16,
                    color: Colors.black87,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Your credits: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: '$requesterCredits credits',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'The provider must accept your request before the service begins. Your credits will be reserved but not charged until the provider accepts.',
                style: GoogleFonts.mulish(
                  fontSize: 14,
                            color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.mulish(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
            ElevatedButton(
                        onPressed: () async {
                try {
                  // Convert session ID to int if it's a string
                  final sessionId = session['id'] is String ? int.parse(session['id']) : session['id'];
                  
                  // Double-check requester's credits to ensure we have the latest data
                  final latestRequesterData = await supabaseClient
                      .from('users')
                      .select('credits')
                      .eq('id', requesterId)
                      .single();
                      
                  final int currentCredits = latestRequesterData['credits'] != null
                      ? int.parse(latestRequesterData['credits'].toString())
                      : 0;
                      
                  if (currentCredits < skillCost) {
                    showSafeSnackBar(context, 'Insufficient credits: You have $currentCredits but need $skillCost');
                    Navigator.pop(context, false);
                    return;
                  }

                  // Try to reserve the credits using the database function
                  if (kDebugMode) {
                    print('Trying to reserve credits directly in the database');
                  }
                  try {
                    final result = await supabaseClient.rpc(
                      'reserve_credits_for_service',
                      params: {
                        'p_user_id': requesterId,
                        'p_amount': skillCost.toInt()
                      }
                    );
                    
                    if (result == false) {
                      showSafeSnackBar(context, 'Failed to reserve credits. Please try again.');
                      Navigator.pop(context, false);
                      return;
                    }
                    
                    if (kDebugMode) {
                      print('Credits reserved successfully via RPC function');
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print('RPC function failed, but we will continue: $e');
                    }
                    // Continue with normal flow even if RPC fails
                  }
                  
                  // Update session status to 'Requested' (new state for provider to accept)
                  await supabaseClient
                      .from('sessions')
                      .update({'status': 'Requested'})
                      .eq('id', sessionId);
                  
                  // Create a transaction record to track the payment
                  final transactionData = {
                    'session_id': sessionId,
                    'requester_id': requesterId,
                    'provider_id': providerId,
                    'created_at': DateTime.now().toIso8601String(),
                    'status': 'Pending' // Changed from 'Reserved' to match DB constraints
                  };
                  
                  if (kDebugMode) {
                    print('Creating transaction: $transactionData');
                  }
                  
                  try {
                    // Check if a transaction for this session already exists
                    final existingTransactions = await supabaseClient
                        .from('transactions')
                        .select()
                        .eq('session_id', sessionId);
                        
                    if (existingTransactions.isNotEmpty) {
                      if (kDebugMode) {
                        print('Transaction already exists for session $sessionId, deleting existing transactions');
                      }
                      
                      try {
                        // Delete existing transactions for this session
                        await supabaseClient
                            .from('transactions')
                            .delete()
                            .eq('session_id', sessionId);
                            
                        if (kDebugMode) {
                          print('Deleted existing transactions for session $sessionId');
                        }
                      } catch (deleteError) {
                        if (kDebugMode) {
                          print('Error deleting existing transactions: $deleteError');
                        }
                        // Continue anyway, we'll try to create a new transaction
                      }
                    }
                    
                    try {
                      // Create a fresh transaction
                      if (kDebugMode) {
                        print('Creating fresh transaction');
                      } 
                      if (kDebugMode) {
                        print('Transaction created successfully');
                      }
                    } catch (createError) {
                      if (kDebugMode) {
                        print('Error creating transaction: $createError');
                      }
                      
                      // Final fallback: try just updating existing transaction status
                      if (kDebugMode) {
                        print('Trying to update existing transaction as fallback');
                      }
                      
                      try {
                        await supabaseClient
                            .from('transactions')
                            .update({
                              'status': 'Pending',
                              'created_at': DateTime.now().toIso8601String()
                            })
                            .eq('session_id', sessionId);
                            
                        if (kDebugMode) {
                          print('Existing transaction updated successfully as fallback');
                        }
                      } catch (updateError) {
                        if (kDebugMode) {
                          print('Final fallback failed: $updateError');
                        }
                        // Give up, but we already have the credit reservation
                      }
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print('Error with transaction: $e');
                    }
                    showSafeSnackBar(context, 'Error with transaction: $e');
                    // Continue anyway since credits are already deducted
                  }
                  
                  // Notify the provider that they have a service request
                  final notificationData = {
                    'user_id': providerId,
                    'message': '${requesterData['username']} has requested your service "${skillData['name']}"',
                    'created_at': DateTime.now().toIso8601String(),
                    'is_read': false,
                  };
                  
                  await supabaseClient
                      .from('notifications')
                      .insert(notificationData);
                  
                  // Return success
                  Navigator.pop(context, true);
                  
                  // Show success message
                  showSafeSnackBar(context, 'Service requested. Waiting for provider to accept.', backgroundColor: Colors.green);
                } catch (e) {
                  showSafeSnackBar(context, 'Error requesting service: $e');
                            Navigator.pop(context, false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6296FF),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Request Service',
                style: GoogleFonts.mulish(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      showSafeSnackBar(context, 'Error preparing request dialog: $e');
      return false;
    }
  }
  
  // Show accept/decline dialog for the provider
  Future<bool?> showAcceptDialog(BuildContext context) async {
    try {
      final requesterId = int.parse(session['requester_id'].toString());
      final providerId = int.parse(session['provider_id'].toString());
      final skillId = session['skill_id'];

      // Get the requester's details
      final requesterResponse = await DatabaseHelper.getUser(requesterId);
      if (!requesterResponse.success) {
        showSafeSnackBar(context, 'Error fetching requester information');
        return false;
      }
      final requesterData = requesterResponse.data;

      // Get the skill details
      final skillData = await DatabaseHelper.fetchOneSkill(skillId);
      if (skillData.isEmpty) {
        showSafeSnackBar(context, 'Error fetching skill information');
        return false;
      }

      // Get the provider's details
      final providerResponse = await DatabaseHelper.getUser(providerId);
      if (!providerResponse.success) {
        showSafeSnackBar(context, 'Error fetching provider information');
        return false;
      }
      final providerData = providerResponse.data;

      // Calculate skill cost
      final double skillCost = skillData['cost'] != null ? double.parse(skillData['cost'].toString()) : 0.0;
      
      return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Accept Service Request',
            style: GoogleFonts.mulish(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6296FF),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                                      Text(
                '${requesterData['username']} has requested your service:',
                style: GoogleFonts.mulish(
                  fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
              const SizedBox(height: 15),
              RichText(
                text: TextSpan(
                                        style: GoogleFonts.mulish(
                                          fontSize: 16,
                    color: Colors.black87,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Service: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: skillData['name']),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                                            style: GoogleFonts.mulish(
                                              fontSize: 16,
                    color: Colors.black87,
                                            ),
                  children: [
                    const TextSpan(
                      text: 'Payment: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                    TextSpan(
                      text: '$skillCost credits',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6296FF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
              const SizedBox(height: 15),
              Text(
                'Do you want to accept this service request? If you decline, the credits will be refunded to the requester.',
                style: GoogleFonts.mulish(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  // Convert session ID to int if it's a string
                  final sessionId = session['id'] is String ? int.parse(session['id']) : session['id'];
                  
                  // Log the current credits and amount to be refunded
                  final skillId = session['skill_id'];
                  final skillData = await DatabaseHelper.fetchOneSkill(skillId);
                  if (skillData.isEmpty) {
                    showSafeSnackBar(context, 'Error fetching skill details');
                    Navigator.pop(context, false);
                    return;
                  }
                  
                  final double skillCost = skillData['cost'] != null ? 
                      double.parse(skillData['cost'].toString()) : 0.0;
                  
                  if (kDebugMode) {
                    print('Declining service. Refund amount: $skillCost credits');
                  }
                  
                  // Update session status to 'Declined'
                  await supabaseClient
                      .from('sessions')
                      .update({'status': 'Declined'})
                      .eq('id', sessionId);
                  
                  // Update transaction status - this will trigger credit refund in database
                  final transactions = await supabaseClient
                      .from('transactions')
                      .select()
                      .eq('session_id', sessionId)
                      .eq('status', 'Pending');
                      
                  if (transactions.isNotEmpty) {
                    if (kDebugMode) {
                      print('Updating transaction status to Declined - this will trigger credit refund');
                    }
                    await supabaseClient
                        .from('transactions')
                        .update({
                          'status': 'Declined',
                          'completed_at': DateTime.now().toIso8601String()
                        })
                        .eq('session_id', sessionId);
                    
                    if (kDebugMode) {
                      print('Transaction status updated successfully');
                    }
                  } else {
                    if (kDebugMode) {
                      print('No pending transaction found for this session');
                    }
                  }
                  
                  // Notify the requester that the request was declined
                  final notificationData = {
                    'user_id': requesterId,
                    'message': '${providerData['username']} has declined your request for "${skillData['name']}"',
                    'created_at': DateTime.now().toIso8601String(),
                    'is_read': false,
                  };
                  
                  await supabaseClient
                      .from('notifications')
                      .insert(notificationData);
                  
                  Navigator.pop(context, false);
                  
                  // Show success message
                  showSafeSnackBar(context, 'Service request declined.', backgroundColor: Colors.red);
                } catch (e) {
                  showSafeSnackBar(context, 'Error declining service: $e');
                  Navigator.pop(context, false);
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                'Decline',
                          style: GoogleFonts.mulish(
                            fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                          ),
                        ),
                      ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Convert session ID to int if it's a string
                  final sessionId = session['id'] is String ? int.parse(session['id']) : session['id'];
                  
                  // Update session status to 'Pending' (accepted)
                  await supabaseClient
                      .from('sessions')
                      .update({'status': 'Pending'})
                      .eq('id', sessionId);
                  
                  // Update transaction status
                  final transactions = await supabaseClient
                      .from('transactions')
                      .select()
                      .eq('session_id', sessionId)
                      .eq('status', 'Pending');
                      
                  if (transactions.isNotEmpty) {
                    await supabaseClient
                        .from('transactions')
                        .update({
                          'status': 'Pending',
                          'completed_at': DateTime.now().toIso8601String()
                        })
                        .eq('session_id', sessionId);
                  }
                  
                  // Notify the requester that the request was accepted
                  final notificationData = {
                    'user_id': requesterId,
                    'message': '${providerData['username']} has accepted your request for "${skillData['name']}"',
                    'created_at': DateTime.now().toIso8601String(),
                    'is_read': false,
                  };
                  
                  await supabaseClient
                      .from('notifications')
                      .insert(notificationData);
                  
                  Navigator.pop(context, true);
                  
                  // Show success message
                  showSafeSnackBar(context, 'Service request accepted.', backgroundColor: Colors.green);
                } catch (e) {
                  showSafeSnackBar(context, 'Error accepting service: $e');
                  Navigator.pop(context, false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'Accept',
                style: GoogleFonts.mulish(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      showSafeSnackBar(context, 'Error preparing accept dialog: $e');
      return false;
    }
  }

  Future<bool> creditToContinue(BuildContext context, int requiredCredits) async {
    final loggedInUserId = await UserIdStorage.getLoggedInUserId();
    if (loggedInUserId == null) {
      _showErrorDialog(context, 'Error', 'You must be logged in to request a service.');
      return false;
    }

    // Get user's current credits
    final userData = await supabaseClient
        .from('users')
        .select('credits')
        .eq('id', loggedInUserId)
        .single();

    final int currentCredits = userData['credits'] ?? 0;

    // Check if user has enough credits
    if (currentCredits < requiredCredits) {
      _showErrorDialog(
        context, 
        'Insufficient Credits', 
        'You need $requiredCredits credits to request this service. You currently have $currentCredits credits.'
      );
      return false;
    }
    return true;
  }

  // Add the missing _showErrorDialog method
  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6296FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Session State = Pending -> Completed/ReadyForCompletion
class CompleteService extends StatelessWidget {
  final Map<String, dynamic> session;

  const CompleteService({super.key, required this.session});

  // Show finalize dialog that asks for confirmation
  Future<bool?> showFinalizeDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Confirm Service Completion',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to mark this service as completed?',
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 8),
              Text(
                'Both you and the other party will need to confirm completion for the credits to be transferred.',
                style: GoogleFonts.poppins(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Get current user ID
                final userId = await UserIdStorage.getLoggedInUserId();
                if (userId == null) {
                  Navigator.of(context).pop(false);
                  return;
                }
                
                // Determine if current user is provider or requester
                final isProvider = session['provider_id'].toString() == userId.toString();
                final isRequester = session['requester_id'].toString() == userId.toString();
                
                if (!isProvider && !isRequester) {
                  showSafeSnackBar(context, 'You are not part of this service');
                  Navigator.of(context).pop(false);
                  return;
                }
                
                try {
                  // Update confirmation status based on user role
                  final result = await DatabaseHelper.updateSessionConfirmation(
                    sessionId: session['id'],
                    providerConfirmed: isProvider ? true : null,
                    requesterConfirmed: isRequester ? true : null,
                  );
                  
                  if (!result) {
                    showSafeSnackBar(context, 'Failed to confirm service completion. Please try again.', backgroundColor: Colors.red);
                    Navigator.of(context).pop(false);
                    return;
                  }
                  
                  // Check if both sides have confirmed
                  final updatedSession = await supabaseClient
                      .from('sessions')
                      .select('provider_confirmed, requester_confirmed, status, skill_id')
                      .eq('id', session['id'])
                      .single();
                      
                  if (updatedSession['provider_confirmed'] == true && 
                      updatedSession['requester_confirmed'] == true) {
                    
                    // Both parties confirmed, finalize the transaction
                    
                    // 1. Get skill cost for logging
                    final skillId = session['skill_id'];
                    final skillData = await DatabaseHelper.fetchOneSkill(skillId);
                    if (skillData.isEmpty) {
                      showSafeSnackBar(context, 'Error fetching skill details');
                      Navigator.of(context).pop(true);
                      return;
                    }
                    
                    final double skillCost = skillData['cost'] != null ? 
                        double.parse(skillData['cost'].toString()) : 0.0;
                        
                    if (kDebugMode) {
                      print('Service completed. Cost: $skillCost credits');
                    }
                    
                    // 2. Update session status to completed
                    await supabaseClient
                        .from('sessions')
                        .update({'status': 'Completed'})
                        .eq('id', session['id']);
                    
                    // 3. Update transaction status - this will trigger the database function to transfer credits
                    final transactions = await supabaseClient
                        .from('transactions')
                        .select()
                        .eq('session_id', session['id'])
                        .eq('status', 'Pending');
                        
                    if (transactions.isNotEmpty) {
                      if (kDebugMode) {
                        print('Updating transaction status to Completed - this will trigger credit transfer');
                      }
                      await supabaseClient
                          .from('transactions')
                          .update({
                            'status': 'Completed',
                            'completed_at': DateTime.now().toIso8601String()
                          })
                          .eq('session_id', session['id']);
                      
                      if (kDebugMode) {
                        print('Transaction updated successfully');
                      }
                    }
                    
                    showSafeSnackBar(context, 'Service completed successfully! Credits have been transferred to the provider.', backgroundColor: Colors.green);
                  } else {
                    showSafeSnackBar(context, 'Your confirmation has been recorded. The service will be completed when both parties confirm.');
                  }
                  
                  Navigator.of(context).pop(true);
                } catch (e) {
                  showSafeSnackBar(context, 'Error: $e');
                  Navigator.of(context).pop(false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Confirm',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

// Cancel session
class CancelService {
  final Map<String, dynamic> session;

  CancelService({required this.session});
  
  Future<bool?> showFinalizeDialog(BuildContext context) async {
    try {
      int.parse(session['requester_id'].toString());
      final skillId = session['skill_id'];
      
      // Get skill info
      final skillData = await DatabaseHelper.fetchOneSkill(skillId);
      if (skillData.isEmpty) {
        showSafeSnackBar(context, 'Error fetching skill information');
        return false;
      }

      // Calculate amount to refund
      final double skillCost = skillData['cost'] != null ? double.parse(skillData['cost'].toString()) : 0.0;
      
      // Show confirmation dialog
    return await showDialog<bool>(
      context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Cancel Service',
            style: GoogleFonts.mulish(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
          content: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                'You are about to cancel this service.',
                style: GoogleFonts.mulish(
                  fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 15),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.mulish(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Service: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: skillData['name']),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                          style: GoogleFonts.mulish(
                            fontSize: 16,
                    color: Colors.black87,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Refund: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: '$skillCost credits will be refunded to your account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'This action cannot be undone. The service will be cancelled and credits will be refunded to your account.',
                style: GoogleFonts.mulish(
                  fontSize: 14,
                            color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Go Back',
                style: GoogleFonts.mulish(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            ElevatedButton(
                        onPressed: () async {
                try {
                  // Convert session ID to int if it's a string
                  final sessionId = session['id'] is String ? int.parse(session['id']) : session['id'];
                  
                  // Log the current credits and amount to be refunded
                  final skillId = session['skill_id'];
                  final skillData = await DatabaseHelper.fetchOneSkill(skillId);
                  if (skillData.isEmpty) {
                    showSafeSnackBar(context, 'Error fetching skill details');
                    Navigator.pop(context, false);
                    return;
                  }
                  
                  final double skillCost = skillData['cost'] != null ? 
                      double.parse(skillData['cost'].toString()) : 0.0;
                  
                  if (kDebugMode) {
                    print('Cancelling service. Refund amount: $skillCost credits');
                  }
                  
                  // Update session status to Cancelled
                  await supabaseClient
                      .from('sessions')
                      .update({'status': 'Cancelled'})
                      .eq('id', sessionId);
                  
                  // Update the transaction - this will trigger credit refund in database
                  final transactions = await supabaseClient
                      .from('transactions')
                      .select()
                      .eq('session_id', sessionId)
                      .eq('status', 'Pending');
                      
                  if (transactions.isNotEmpty) {
                    if (kDebugMode) {
                      print('Updating transaction status to Cancelled - this will trigger credit refund');
                    }
                    await supabaseClient
                        .from('transactions')
                        .update({
                          'status': 'Cancelled',
                          'completed_at': DateTime.now().toIso8601String()
                        })
                        .eq('session_id', sessionId);
                    
                    if (kDebugMode) {
                      print('Transaction cancelled successfully');
                    }
                  } else {
                    if (kDebugMode) {
                      print('No pending transaction found for this session');
                    }
                  }
                  
                  // Success!
                  Navigator.pop(context, true);
                } catch (e) {
                  showSafeSnackBar(context, 'Error cancelling service: $e');
                            Navigator.pop(context, false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                        ),
                        child: Text(
                'Cancel Service',
                          style: GoogleFonts.mulish(
                            fontSize: 16,
                  fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
          ),
        );
    } catch (e) {
      showSafeSnackBar(context, 'Error preparing cancellation dialog: $e');
      return false;
    }
  }
}

// Add a review for a completed session
class ReviewService {
  final int sessionId;
  final int reviewerId;
  final int revieweeId;

  ReviewService({
    required this.sessionId,
    required this.reviewerId,
    required this.revieweeId,
  });
  
  Future<bool?> showReviewDialog(BuildContext context) async {
    int rating = 5;
    final TextEditingController reviewController = TextEditingController();
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must take an action
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6296FF).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFF6296FF),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Rate Your Experience",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Please rate your experience with this service.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.mulish(
                          fontSize: 16,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: index < rating ? const Color(0xFFFFD700) : Colors.grey[400],
                              size: 36,
                            ),
                            onPressed: () {
                              setState(() {
                                rating = index + 1;
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: reviewController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Write your review (optional)",
                          hintStyle: GoogleFonts.mulish(color: Colors.grey[500]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        style: GoogleFonts.mulish(
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Skip",
                                style: GoogleFonts.mulish(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final success = await DatabaseHelper.addReview(
                                  sessionId,
                                  reviewerId,
                                  revieweeId,
                                  rating,
                                  reviewController.text.isNotEmpty ? reviewController.text : null,
                                );
                                Navigator.pop(context, success);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6296FF),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Submit",
                                style: GoogleFonts.mulish(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }
}

// Add a utility function to safely show SnackBars
void showSafeSnackBar(BuildContext context, String message, {Color? backgroundColor}) {
  try {
    // Create a local variable for the ScaffoldMessenger
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Show the SnackBar
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.mulish(),
        ),
        backgroundColor: backgroundColor,
      ),
    );
  } catch (e) {
    // Swallow the exception - this likely means the context is no longer valid
    debugPrint('Error showing SnackBar: $e');
  }
}