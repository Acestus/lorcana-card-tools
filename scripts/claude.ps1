                                                                    
param(                                                                                                           
    [Parameter(Mandatory=$true)]                                                                                 
    [string]$Message                                                                                             
   )                                                                                                                
                                                                                                                    
ssh violet "openclaw agent --message '$Message' --session-id main"
