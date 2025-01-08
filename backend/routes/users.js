const express = require("express");
const supabase = require("../db/supabase");
const router = express.Router();

// GET: /api/users, fetch ALL users
router.get("", async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('users')
            .select('*')

        res.status(200).json({ users: data });

        if (error) {
            throw error;
        }
    } catch (err) {
        console.error('Error fetching users: ', err.message);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// GET: /api/users/{user_id}, fetch specific user with user_id
router.get("/:user_id", async (req, res) => {
    const user_id = req.params.user_id;
    try {
        const { data, error } = await supabase
            .from('users')
            .select('username, email, phone_number, bio, credits')
            .eq('id', user_id)
            .single();

        res.status(200).json({ user: data });

        if (error) {
            throw error;
        }
    } catch (err) {
        console.error('Error fetching user: ', err.message);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// PATCH: /api/users/{user_id}, update user by user_id
router.patch("/:user_id", async (req, res) => {
    const user_id = req.params.user_id;
    const { email, password, phone_number, bio } = req.body;

    // check for empty or invalid request body
    if (!email && !password && !phone_number && !bio) {
        return res.status(400).json({ error: 'At least one field required' });
    }

    try {
        const updates = {};

        if (email) {
            updates.email = email;
        }

        if (password) {
            const hashedPassword = await hash(password);
            updates.password = hashedPassword;
        }

        if (phone_number) {
            updates.phone_number = phone_number;
        }

        if (bio) {
            updates.bio = bio;
        }

        const { data, error } = await supabase
            .from('users')
            .update(updates)
            .eq('id', user_id)
            .single()
            .select()

        if (error) {
            console.error(error);
            return res.status(500).json({ error: 'Error updating user' });
        }

        return res.status(200).json({ message: 'Successfully updated user', user: data });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: 'Internal server error' });
    }
});

// DELETE: /api/users/{user_id}, delete user by user_id
router.delete('/:user_id', async (req, res) => {
    const user_id = req.params.user_id;

    try {
        const { data, error } = await supabase
            .from('users')
            .delete()
            .eq('id', user_id)
            .single()
            .select();

        if (error) {
            console.error(error);
            return res.status(404).json({ error: 'User not found or could not be deleted' });
        }

        return res.status(200).json({ message: 'User deleted successfully', user: data });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
