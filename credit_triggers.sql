-- Create a trigger function to handle credit transfers automatically
CREATE OR REPLACE FUNCTION process_transaction_status_change()
RETURNS TRIGGER AS $$
DECLARE
  transaction_record RECORD;
  skill_record RECORD;
  requester_credits INTEGER;
  provider_credits INTEGER;
  cost_amount INTEGER;
BEGIN
  -- Get the transaction record with related data
  SELECT * INTO transaction_record FROM transactions WHERE id = NEW.id;
  
  -- Get the skill details to determine the cost
  SELECT s.cost INTO skill_record 
  FROM skills s 
  JOIN sessions sess ON sess.skill_id = s.id
  WHERE sess.id = transaction_record.session_id;
  
  -- Get the cost amount
  cost_amount := COALESCE(skill_record.cost, 0);
  
  -- Process based on the status change
  IF NEW.status = 'Completed' AND OLD.status = 'Pending' THEN
    -- When a transaction is completed, transfer credits to the provider
    
    -- Get current credits
    SELECT credits INTO requester_credits FROM users WHERE id = transaction_record.requester_id;
    SELECT credits INTO provider_credits FROM users WHERE id = transaction_record.provider_id;
    
    -- Add credits to provider
    UPDATE users SET credits = provider_credits + cost_amount 
    WHERE id = transaction_record.provider_id;
    
    RETURN NEW;
    
  ELSIF NEW.status = 'Cancelled' AND (OLD.status = 'Pending' OR OLD.status = 'Reserved') THEN
    -- When a transaction is cancelled, refund credits to the requester
    
    -- Get current credits
    SELECT credits INTO requester_credits FROM users WHERE id = transaction_record.requester_id;
    
    -- Refund credits to requester
    UPDATE users SET credits = requester_credits + cost_amount 
    WHERE id = transaction_record.requester_id;
    
    RETURN NEW;
    
  ELSIF NEW.status = 'Declined' AND (OLD.status = 'Pending' OR OLD.status = 'Reserved') THEN
    -- When a transaction is declined, refund credits to the requester
    
    -- Get current credits
    SELECT credits INTO requester_credits FROM users WHERE id = transaction_record.requester_id;
    
    -- Refund credits to requester
    UPDATE users SET credits = requester_credits + cost_amount 
    WHERE id = transaction_record.requester_id;
    
    RETURN NEW;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for transactions table
DROP TRIGGER IF EXISTS transaction_status_change_trigger ON transactions;
CREATE TRIGGER transaction_status_change_trigger
AFTER UPDATE OF status ON transactions
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION process_transaction_status_change();

-- Function to handle initial credit reservation
CREATE OR REPLACE FUNCTION reserve_credits_for_service(
  p_user_id INTEGER, 
  p_amount INTEGER
) 
RETURNS BOOLEAN AS $$
DECLARE
  current_credits INTEGER;
BEGIN
  -- Get current credits
  SELECT credits INTO current_credits FROM users WHERE id = p_user_id;
  
  -- Check if user has enough credits
  IF current_credits < p_amount THEN
    RETURN FALSE;
  END IF;
  
  -- Deduct credits
  UPDATE users SET credits = current_credits - p_amount WHERE id = p_user_id;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 