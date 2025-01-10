const express = require("express");
const supabase = require("../db/supabase");
const router = express.Router();

router.get("/user/:userId", async (req, res) =>{

    const userId = parseInt(req.params.userId, 10);
    const { data, error } = await supabase
        .from('chats')
        .select(`id, user1_id, user2_id, last_message,last_updated`)
        .or(`user1_id.eq.${userId},user2_id.eq.${userId}`)
        .order('last_updated', { ascending: false });

        if (error) {
        console.error('Error fetching chats:', error);
        }
        const formattedData = data.map(chat => ({
            chat_id: chat.id,
            last_message: chat.last_message,
            last_updated: chat.last_updated,
            other_user_id: chat.user1_id === userId ? chat.user2_id : chat.user1_id,
        }));
        res.status(200).json(formattedData);
});


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


router.post("/get-or-create", async (req, res) => {
    const {user1Id, user2Id} = req.body;

    const {data: existingChat, error: findError} = await supabase
        .from('chats')
        .select('*')
        .or(`(user1_id.eq.${user1Id},user2_id.eq.${user2Id}), (user1_id.eq.${user2Id},user2_id.eq.${user1Id})`)
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
            last_message: null,
            last_updated: new Date().toISOString(),
        })
        .select();

    if(createError){
        console.error("Error creating chat: ", createError);
        return res.status(500).json({error: createError.message});
    }

    res.status(200).json({chat_id: newChat[0].id});
});


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

module.exports = router;
