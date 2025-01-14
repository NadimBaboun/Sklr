import 'package:flutter/material.dart';
import 'package:sklr/database/database.dart';

// Session State = Idle -> Pending
class RequestService {
  final Map<String, dynamic> session;

  RequestService({required this.session});

  Future<bool?> showRequestDialog(BuildContext context) async {
    Widget confirmButton = TextButton(
      child: const Text("I Understand",
      style: TextStyle(
        color: Color(0xFF6296FF)
        ),
      ),
      onPressed: () async {
        // check that requester has funds
        final requester = await DatabaseHelper.fetchUserFromId(session['requester_id']);
        if (!requester.success) { // failed to fetch user
          Navigator.of(context, rootNavigator: true).pop(false);
        }
        if (requester.data['credits'] <= 0) { // user has insufficient funds
          Navigator.of(context, rootNavigator: true).pop(false);
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Payment unsuccessful'),
                content: const Text('You don\'t have sufficient funds'),
                actions: [
                  TextButton(
                    child: const Text('Dismiss'),
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop(false);
                    },
                  )
                ]
              );
            }
          );
        }
        else { // user has sufficient funds
          // Create transaction: subtracts credit from requester, creates transaction entity, updates session status
          await DatabaseHelper.createTransaction(session['id']);
          Navigator.of(context, rootNavigator: true).pop(true);
        }
      },
    );

    Widget cancelButton = TextButton(
      child: const Text("Cancel",
      style: TextStyle(
        color: Color(0xFF6296FF)
        ),),
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop(false);
      },
    );

    AlertDialog requestDialog = AlertDialog(
      backgroundColor: Colors.white,
      title: const Text("Confirm Request"),
      content: const Text("Please note that canceling a request will NOT refund your credit."),
      actions: [
        confirmButton,
        cancelButton,
      ],
  
    );

    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return requestDialog;
      },
    );
  }
}


// Session State = Pending -> Idle
class CompleteService {
  final Map<String, dynamic> session;

  CompleteService({required this.session});
  
  Future<bool?> showFinalizeDialog(BuildContext context) async {
    Widget confirmButton = TextButton(
      child: const Text("Complete",
      style: TextStyle(
        color: Color(0xFF6296FF)
        ),),
      onPressed: () async {
        // fetch transaction
        final transaction = await DatabaseHelper.fetchTransactionFromSession(session['id']);
        if (!transaction.success) { // failed to fetch transaction
          Navigator.of(context, rootNavigator: true).pop(false);
        }
        // finalize transaction, set session status to 'Idle', award provider with credit, remove transaction
        final result = await DatabaseHelper.finalizeTransaction(transaction.data['id']);
        Navigator.of(context, rootNavigator: true).pop(result);
      },
    );

    Widget cancelButton = TextButton(
      child: const Text("Cancel",
      style: TextStyle(
        color: Color(0xFF6296FF)
        ),
      ),
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop(false);
      },
    );

    AlertDialog requestDialog = AlertDialog(
      backgroundColor: Colors.white,
      title: const Text("Confirm Request"),
      content: const Text("Are you sure you want to mark this session as complete? Once finalized, no further changes can be made."),
      actions: [
        confirmButton,
        cancelButton,
      ],
    );

    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return requestDialog;
      },
    );
  }
}

// Cancel session
class CancelService {
  final Map<String, dynamic> session;

  CancelService({required this.session});
  
  Future<bool?> showFinalizeDialog(BuildContext context) async {
    Widget cancelButton = TextButton(
      child: const Text("Cancel",
      style: TextStyle(
        color: Color(0xFF6296FF)
        ),),
      onPressed: () async {
        // cancel session
        // basically the same thing as complete ..?
        // fetch transaction
        final transaction = await DatabaseHelper.fetchTransactionFromSession(session['id']);
        if (!transaction.success) { // failed to fetch transaction
          Navigator.of(context, rootNavigator: true).pop(false);
        }
        // finalize transaction, set session status to 'Idle', award provider with credit, remove transaction
        final result = await DatabaseHelper.finalizeTransaction(transaction.data['id']);
        Navigator.of(context, rootNavigator: true).pop(result);
      },
    );

    Widget dismissButton = TextButton(
      child: const Text("Dismiss",
      style: TextStyle(
        color: Color(0xFF6296FF)
        ),),
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop(false);
      },
    );

    AlertDialog requestDialog = AlertDialog(
      backgroundColor: Colors.white,
      title: const Text("Cancel Request"),
      content: const Text("Are you sure you want to cancel this session? You will not be refunded."),
      actions: [
        cancelButton,
        dismissButton,
      ],
    );

    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return requestDialog;
      },
    );
  }
}
