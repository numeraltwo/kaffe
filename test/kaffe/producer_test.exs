defmodule Kaffe.ProducerTest do
  use ExUnit.Case, async: true

  alias Kaffe.Producer

  @test_partition_count Application.get_env(:kaffe, :test_partition_count)

  setup do
    %{
      client: :client,
      strategy: :round_robin,
      topics: ["topic", "topic2"],
      producer_state: %Kaffe.Producer.State{
        client: :client,
        topics: ["topic", "topic2"],
        partition_details: %{
          topic: %{partition: 0, total: 20},
          topic2: %{partition: 0, total: 20}
        },
        partition_strategy: :round_robin
      }
    }
  end

  test "on initialization Producer determines the number of partitions for each topic", c do
    assert {:ok, %{partition_details: details}} = Producer.init([c.client, c.topics, c.strategy])
    c.topics
    |> Enum.each(fn(topic) ->
      assert %{partition: 0, total: @test_partition_count} == details[String.to_atom(topic)]
    end)
  end

  test "produce_sync(key, value) produces a message to the first configured topic", c do
    Producer.handle_call({:produce_sync, "key", "value"}, self, c.producer_state)
    assert_receive [:produce_sync, "topic", 0, "key", "value"]
  end

  test "produce_sync(topic, key, value) produces a message to the specific topic", c do
    Producer.handle_call({:produce_sync, "topic2", "key", "value"}, self, c.producer_state)
    assert_receive [:produce_sync, "topic2", 0, "key", "value"]
  end

  test "produce_sync(topic, partition, key, value) produces a message to the specific topic/partition", c do
    partition = 99
    Producer.handle_call(
      {:produce_sync, "topic2", partition, "key", "value"}, self, c.producer_state)
    assert_receive [:produce_sync, "topic2", ^partition, "key", "value"]
  end

  test "producer uses the configured partition selection strategy when it chooses the next partition", c do
    starting_state = c.producer_state
    assert starting_state.partition_strategy == :round_robin

    {:reply, :ok, new_state} = Producer.handle_call(
      {:produce_sync, "topic", "key", "value"}, self, starting_state)
    assert_receive [:produce_sync, "topic", 0, "key", "value"]

    {:reply, :ok, new_state} = Producer.handle_call(
      {:produce_sync, "topic", "key", "value"}, self, new_state)
    assert_receive [:produce_sync, "topic", 1, "key", "value"]

    Producer.handle_call(
      {:produce_sync, "topic", "key", "value"}, self, new_state)
    assert_receive [:produce_sync, "topic", 2, "key", "value"]
  end

  test "producer does not use the partition selection strategy when given direct partition", c do
    {:reply, :ok, new_state} = Producer.handle_call(
     {:produce_sync, "topic", 0, "key", "value"}, self, c.producer_state)
    assert_receive [:produce_sync, "topic", 0, "key", "value"]

    Producer.handle_call(
      {:produce_sync, "topic", 0, "key", "value"}, self, new_state)
    assert_receive [:produce_sync, "topic", 0, "key", "value"]
  end
end
