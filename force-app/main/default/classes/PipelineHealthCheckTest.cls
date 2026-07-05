@IsTest
private class PipelineHealthCheckTest {
    @IsTest
    static void testStatus() {
        String result = PipelineHealthCheck.status();
        Assert.areEqual('ok', result, 'PipelineHealthCheck.status() should return ok');
    }
}
