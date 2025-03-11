const express = require("express");
const supabase = require("../db/supabase");
const router = express.Router();

//gets chats for homepage : lastmessage, lastupdated
router.get("/user/:userId", async (req, res) => {
    const userId = parseInt(req.params.userId, 10);
    
    try {
        // Get all chats for the user with unread count
        const { data: chats, error: chatError } = await supabase
            .from('chats')
            .select(`
                id,
                user1_id,
                user2_id,
                last_message,
                last_updated,
                sessions!inner (
                    skill_id,
                    skills (
                        name
                    )
                )
            `)
            .or(`user1_id.eq.${userId},user2_id.eq.${userId}`)
            .order('last_updated', { ascending: false });

        if (chatError) throw chatError;

        // Get unread counts for each chat
        const chatsWithUnread = await Promise.all(chats.map(async (chat) => {
            // Get unread messages count
            const { count: unreadCount, error: countError } = await supabase
                .from('messages')
                .select('*', { count: 'exact', head: true })
                .eq('chat_id', chat.id)
                .eq('read', false)
                .neq('sender_id', userId);

            if (countError) throw countError;

            return {
                chat_id: chat.id,
                last_message: chat.last_message,
                last_updated: chat.last_updated,
                skill: chat.sessions?.skills?.name,
                other_user_id: chat.user1_id === userId ? chat.user2_id : chat.user1_id,
                unread_count: unreadCount || 0
            };
        }));

        res.status(200).json(chatsWithUnread);
    } catch (err) {
        console.error('Error fetching chats:', err);
        res.status(500).json({ error: 'Failed to fetch chats' });
    }
});

//getting messages in a chat
router.get("/:chatId/messages", async (req, res) => {
    const chatId = req.params.chatId;
    const {data, error} = await supabase
        .from('messages')
        .select('*')
        .eq('chat_id', chatId)
        .order('timestamp', {ascending: true});

    if(error){
        console.error("Error fetching messages: ", error);
        return res.status(500).json({error: error.messages});
    }

    res.status(200).json(data);
});

//creates or finds chat for user
router.post("/get-or-create", async (req, res) => {
    const { user1Id, user2Id, session_id } = req.body;

    const {data: existingChat, error: findError} = await supabase
        .from('chats')
        .select('*')
        .or(
            `and(user1_id.eq.${user1Id}, user2_id.eq.${user2Id}, session_id.eq.${session_id}),and(user1_id.eq.${user2Id}, user2_id.eq.${user1Id}, session_id.eq.${session_id})`
        )
        .limit(1);

    if(findError){
        console.error("Error checking chat: ", findError);
        return res.status(500).json({error: findError.message});
    }

    if(existingChat.length > 0) {
        return res.status(200).json({chat_id: existingChat[0].id});
    }

    const { data:newChat, error: createError } = await supabase
        .from('chats')
        .insert({
            user1_id: user1Id,
            user2_id: user2Id,
            session_id: session_id,
            last_message: null,
            last_updated: new Date().toISOString(),
        })
        .select();

    console.log(newChat);

    if(createError){
        console.error("Error creating chat: ", createError);
        return res.status(500).json({error: createError.message});
    }

    res.status(200).json({chat_id: newChat[0].id});
});

//sends chat
router.post("/:chatId/message", async (req, res) => {
    const chatId = req.params.chatId;
    const { senderId, message} = req.body;

    const { error: messageError } = await supabase
        .from('messages')
        .insert({
            chat_id: chatId,
            sender_id: senderId,
            message: message,
            timestamp: new Date().toISOString(),
            read: false,
        });

    if(messageError){
        console.error("Error sending a chat: ", messageError)
        return res.status(500).json({error: messageError.message});
    }

    const { error: updateError} = await supabase
        .from('chats')
        .update({
            last_message: message,
            last_updated: new Date().toISOString(),
        })
        .eq('id', chatId);
    
    if(updateError){
        console.error("Error updating chat:", updateError);
        return res.status(500).json({error: updateError});
    }

    res.status(200).json({ success: true});
});

// GET: /api/chat/session/{chat_id}
router.get("/session/:chatId", async (req, res) => {
    const chatId = req.params.chatId;

    try {
        // step 1: fetch session_id from 'chats'
        const { data: chat_data, error: chat_error } = await supabase
            .from('chats')
            .select('session_id')
            .eq('id', chatId)
            .single();

        if (chat_error) {
            throw chat_error;
        }

        if (!chat_data || !chat_data['session_id']) {
            throw new Error('No session_id found for the given chat_id');
        }

        const sessionId = chat_data['session_id'];

        // step 2: fetch * from 'sessions'
        const { data, error } = await supabase
            .from('sessions')
            .select("*")
            .eq('id', sessionId)
            .single();

        if (error) {
            throw error;
        }

        res.status(200).json(data);
    } catch (err) {
        console.error('Error fetching user: ', err.message);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// GET: /api/chat/unread/:userId
router.get("/unread/:userId", async (req, res) => {
    const userId = parseInt(req.params.userId, 10);
    
    try {
        // First get all chats for the user
        const { data: chats, error: chatError } = await supabase
            .from('chats')
            .select('id')
            .or(`user1_id.eq.${userId},user2_id.eq.${userId}`);

        if (chatError) throw chatError;

        if (!chats || chats.length === 0) {
            return res.status(200).json({ count: 0 });
        }

        // Get count of unread messages in user's chats where user is not the sender
        const chatIds = chats.map(chat => chat.id);
        const { count, error: countError } = await supabase
            .from('messages')
            .select('*', { count: 'exact', head: true })
            .eq('read', false)
            .neq('sender_id', userId)
            .in('chat_id', chatIds);

        if (countError) throw countError;

        res.status(200).json({ count: count || 0 });
    } catch (err) {
        console.error('Error getting unread count:', err);
        res.status(500).json({ error: 'Failed to get unread message count' });
    }
});

// Add a new endpoint to mark messages as read
router.post("/:chatId/read", async (req, res) => {
    const chatId = req.params.chatId;
    const { userId } = req.body;

    try {
        const { error } = await supabase
            .from('messages')
            .update({ read: true })
            .eq('chat_id', chatId)
            .neq('sender_id', userId);

        if (error) throw error;

        res.status(200).json({ success: true });
    } catch (err) {
        console.error('Error marking messages as read:', err);
        res.status(500).json({ error: 'Failed to mark messages as read' });
    }
});

// DELETE: /api/chat/:chatId
router.delete("/:chatId", async (req, res) => {
    const chatId = req.params.chatId;

    try {
        // First delete all messages in the chat
        const { error: messagesError } = await supabase
            .from('messages')
            .delete()
            .eq('chat_id', chatId);

        if (messagesError) throw messagesError;

        // Then delete the chat itself
        const { error: chatError } = await supabase
            .from('chats')
            .delete()
            .eq('id', chatId);

        if (chatError) throw chatError;

        res.status(200).json({ success: true });
    } catch (err) {
        console.error('Error deleting chat:', err);
        res.status(500).json({ error: 'Failed to delete chat' });
    }
});

// Add notification endpoints for service requests
router.get("/notifications/:userId", async (req, res) => {
    const userId = parseInt(req.params.userId, 10);
    
    try {
        // Get pending service requests where user is the provider
        const { data: pendingRequests, error: requestError } = await supabase
            .from('sessions')
            .select(`
                id,
                requester:requester_id (
                    username
                ),
                skills!inner (
                    name
                )
            `)
            .eq('provider_id', userId)
            .eq('status', 'Pending')
            .eq('notified', false)
            .order('created_at', { ascending: false });

        if (requestError) throw requestError;

        // Format notifications
        const notifications = pendingRequests.map(request => ({
            type: 'service_request',
            session_id: request.id,
            message: `${request.requester.username} requested your service: ${request.skills.name}`,
            timestamp: new Date().toISOString()
        }));

        res.status(200).json(notifications);
    } catch (err) {
        console.error('Error fetching notifications:', err);
        res.status(500).json({ error: 'Failed to fetch notifications' });
    }
});

// Mark notification as read
router.post("/notifications/:sessionId/read", async (req, res) => {
    const sessionId = parseInt(req.params.sessionId, 10);
    
    try {
        const { error } = await supabase
            .from('sessions')
            .update({ notified: true })
            .eq('id', sessionId);

        if (error) throw error;

        res.status(200).json({ success: true });
    } catch (err) {
        console.error('Error marking notification as read:', err);
        res.status(500).json({ error: 'Failed to mark notification as read' });
    }
});

// Get active services for a user
router.get("/sessions/active/:userId", async (req, res) => {
    const userId = parseInt(req.params.userId, 10);
    
    try {
        const { data: sessions, error: sessionError } = await supabase
            .from('sessions')
            .select(`
                id,
                requester:requester_id (
                    id,
                    username
                ),
                provider:provider_id (
                    id,
                    username
                ),
                skills!inner (
                    id,
                    name
                ),
                status,
                created_at
            `)
            .eq('provider_id', userId)
            .eq('status', 'Pending')
            .order('created_at', { ascending: false });

        if (sessionError) throw sessionError;

        const formattedSessions = sessions.map(session => ({
            session_id: session.id,
            skill_name: session.skills.name,
            requester_name: session.requester.username,
            provider_name: session.provider.username,
            status: session.status,
            created_at: session.created_at
        }));

        res.status(200).json(formattedSessions);
    } catch (err) {
        console.error('Error fetching active services:', err);
        res.status(500).json({ error: 'Failed to fetch active services' });
    }
});

// Complete a service
router.post("/sessions/:sessionId/complete", async (req, res) => {
    const sessionId = parseInt(req.params.sessionId, 10);
    
    try {
        const { error } = await supabase
            .from('sessions')
            .update({ status: 'Completed' })
            .eq('id', sessionId);

        if (error) throw error;

        res.status(200).json({ success: true });
    } catch (err) {
        console.error('Error completing service:', err);
        res.status(500).json({ error: 'Failed to complete service' });
    }
});

// Cancel a service
router.post("/sessions/:sessionId/cancel", async (req, res) => {
    const sessionId = parseInt(req.params.sessionId, 10);
    
    try {
        const { error } = await supabase
            .from('sessions')
            .update({ status: 'Cancelled' })
            .eq('id', sessionId);

        if (error) throw error;

        res.status(200).json({ success: true });
    } catch (err) {
        console.error('Error canceling service:', err);
        res.status(500).json({ error: 'Failed to cancel service' });
    }
});

module.exports = router;
