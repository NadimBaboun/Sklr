const express = require("express");
const supabase = require("../db/supabase");
const router = express.Router();

router.get("/user/:user_id", async (req, res) =>{

try {
    const user_id = req.params.user_id;

    const { data, error } = await supabase
        .from('skills')
        .select('*')
        .eq('user_id', user_id);

        if(error){
            return res.status(400).send({error: error.message});
        }

        if(!data || data.length == 0){
            return res.status(404).send({message: "No skill ads found for this user."})
        }

        res.status(200).send(data);
}
catch (err){
    console.error(err);
    res.status(500).send({ error: "Internal server error"});
};


});

module.exports = router;