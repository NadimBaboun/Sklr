const express = require("express");
const supabase = require("../db/supabase");
const router = express.Router();

//fetches all skills
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

//adds a skill
router.post("/", async (req, res) => {
    try{
        const { user_id, name, description, created_at, category} = req.body;

        if(!user_id || !name || !description || !created_at || !category) {
            return res.status(400).send({ error: "Missing required fields"});

        }

        const { data, error } = await supabase
            .from("skills")
            .insert([
                {
                    user_id,
                    name,
                    description,
                    created_at,
                    category,
                },
            ]);
        if(error){
            return res.status(400).send({ error: error.message});
        }

        res.status(201).send({
            message: "Skill added succesfully",
           
        });
    }catch (err){
        console.error(err);
        res.status(500).send({error: "Internal server error"});
    }
});

//deletes a skill
router.delete("/:name/:user_id", async (req, res) => {
    try {
        const { name, user_id } = req.params; 

     
        if (!name || !user_id) {
            return res.status(400).send({ error: "Name and id is required" });
        }

      
        const { data, error } = await supabase
            .from("skills")
            .delete()
            .eq("name", name)
            .eq("user_id", user_id);
            
       
        if (error) {
            return res.status(400).send({ error: error.message });
        }

      
        if ( !data || !data.length || data.length === 0) {
            return res.status(404).send({ error: "Skill not found" });
        }

       
        res.status(200).send({
            message: "Skill deleted successfully",
        });
    } catch (err) {
        console.error(err);
        res.status(500).send({ error: "Internal server error" });
    }
});

module.exports = router;