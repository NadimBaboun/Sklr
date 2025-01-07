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
            .select('*')
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

module.exports = router;
