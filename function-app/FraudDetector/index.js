const { app } = require('@azure/functions');

app.eventHub('FraudDetector', {
    connection: 'EventHubConnection',
    eventHubName: 'transactions',
    cardinality: 'many',
    extraOutputs: [
        {
            type: 'cosmosDB',
            name: 'outputDocument',
            databaseName: 'FraudDB',
            collectionName: 'Transactions',
            connectionStringSetting: 'CosmosDBConnection',
            createIfNotExists: false
        }
    ],
    handler: async (messages, context) => {
        const FRAUD_THRESHOLD = parseFloat(process.env.FRAUD_THRESHOLD) || 1000;
        const VELOCITY_THRESHOLD = parseInt(process.env.VELOCITY_THRESHOLD) || 5;
        
        const documents = [];
        const alerts = [];

        for (const message of messages) {
            const transaction = typeof message === 'string' ? JSON.parse(message) : message;
            
            const riskScore = calculateRiskScore(transaction, FRAUD_THRESHOLD, VELOCITY_THRESHOLD);
            const isFraudulent = riskScore > 0.7;
            
            const document = {
                id: transaction.transactionId,
                accountId: transaction.accountId,
                amount: transaction.amount,
                timestamp: transaction.timestamp,
                merchantId: transaction.merchantId,
                location: transaction.location,
                riskScore: riskScore,
                isFraudulent: isFraudulent,
                processedAt: new Date().toISOString(),
                rules: getRiskReasons(transaction, FRAUD_THRESHOLD)
            };
            
            documents.push(document);
            
            if (isFraudulent) {
                alerts.push({
                    transactionId: transaction.transactionId,
                    accountId: transaction.accountId,
                    amount: transaction.amount,
                    riskScore: riskScore,
                    reason: document.rules
                });
                
                context.log('🚨 FRAUD DETECTED:', JSON.stringify(document, null, 2));
            }
        }
        
        context.extraOutputs.set('outputDocument', documents);
        context.log(`✅ Processed ${messages.length} transactions, ${alerts.length} flagged`);
    }
});

function calculateRiskScore(transaction, fraudThreshold, velocityThreshold) {
    let score = 0;
    if (transaction.amount > fraudThreshold) score += 0.4;
    if (transaction.location && transaction.location.country !== 'US') score += 0.2;
    if (transaction.amount % 100 === 0 && transaction.amount >= 500) score += 0.15;
    const hour = new Date(transaction.timestamp).getHours();
    if (hour >= 0 && hour < 5) score += 0.15;
    if (transaction.transactionCount && transaction.transactionCount > velocityThreshold) score += 0.3;
    return Math.min(score, 1.0);
}

function getRiskReasons(transaction, fraudThreshold) {
    const reasons = [];
    if (transaction.amount > fraudThreshold) reasons.push(`High amount: $${transaction.amount}`);
    if (transaction.location && transaction.location.country !== 'US') reasons.push(`International: ${transaction.location.country}`);
    if (transaction.amount % 100 === 0 && transaction.amount >= 500) reasons.push('Round number');
    const hour = new Date(transaction.timestamp).getHours();
    if (hour >= 0 && hour < 5) reasons.push('Late night');
    if (transaction.transactionCount && transaction.transactionCount > 5) reasons.push('High velocity');
    return reasons;
}
