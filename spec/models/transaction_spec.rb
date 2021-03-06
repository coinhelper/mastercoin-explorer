require "spec_helper"

describe Transaction do
  context "proper app position" do
    it "should get the proper app position field based on the block height and position if the last transaction was a block away" do
      exodus = FactoryGirl.create(:exodus_transaction, block_height: 10)
      exodus.app_position.should be(1)

      earlier_exodus = FactoryGirl.build(:exodus_transaction)

      earlier_exodus.block_height = 8
      earlier_exodus.save

      earlier_exodus.app_position.should be(1)
      exodus.reload.app_position.should be(2)
    end

    it "should get the proper app position field based on the block height and position if the last transaction was in the same block" do
      exodus = FactoryGirl.create(:exodus_transaction, position: 9)
      exodus.app_position.should be(1)

      earlier_exodus = FactoryGirl.build(:exodus_transaction)

      earlier_exodus.position = 7
      earlier_exodus.save

      earlier_exodus.app_position.should be(1)
      exodus.reload.app_position.should be(2)
    end

    it "should get the proper app position field based on the block height and position if the last transaction was in the same block" do
      exodus = FactoryGirl.create(:exodus_transaction, block_height: 9) # 2
      exodus2 = FactoryGirl.create(:exodus_transaction, block_height: 4) # 1
      exodus3 = FactoryGirl.create(:exodus_transaction, block_height: 12)
      exodus4 = FactoryGirl.create(:exodus_transaction, block_height: 8)
      exodus5 = FactoryGirl.create(:exodus_transaction, block_height: 19)
      exodus6 = FactoryGirl.create(:exodus_transaction, block_height: 2)
      exodus7 = FactoryGirl.create(:exodus_transaction, block_height: 19, position: 1)

      exodus6.reload.app_position.should be(1)
      exodus2.reload.app_position.should be(2)
      exodus4.reload.app_position.should be(3)
      exodus.reload.app_position.should be(4)
      exodus3.reload.app_position.should be(5)
      exodus5.reload.app_position.should be(7)
      exodus7.reload.app_position.should be(6)
    end
  end

  context "valid transactions" do
    it "should be able to flag a transaction as valid when it has funds via Exodus" do
      FactoryGirl.create(:exodus_transaction)
      tx = FactoryGirl.create(:simple_send)
      tx.invalid_tx.should == false
    end

    it "should only be able to spend funds once" do
      exodus = FactoryGirl.create(:exodus_transaction)

      tx = FactoryGirl.create(:simple_send)
      tx.invalid_tx.should eq(false)

      tx2 = FactoryGirl.build(:simple_send)
      tx2.position = tx.position + 1 # Created after the first one so should be invalid
      tx2.save

      tx2.invalid_tx.should eq(true)
    end

    it "should not double spend transactions but if funds are received in block it can use those" do
      FactoryGirl.create(:exodus_transaction)

      a = FactoryGirl.build(:exodus_transaction)
      a.receiving_address = "OTHERADDRESS"
      a.save

      tx = FactoryGirl.create(:simple_send)
      tx.invalid_tx.should == false
      # It had just enough for these funds

      tx2 = FactoryGirl.build(:simple_send)
      tx2.position = tx.position + 1
      tx2.save
      # We don't have enough funds for this one

      tx3 = FactoryGirl.build(:simple_send)
      tx3.receiving_address = tx2.address
      tx3.position = tx2.position + 1
      tx3.address = a.receiving_address
      tx3.save
      # We just received fresh funds, hurray

      tx4 = FactoryGirl.build(:simple_send)
      tx4.position = tx3.position + 1
      tx4.save
      # This is now funded, woop woop

      tx2.invalid_tx.should eq(true)
      tx3.invalid_tx.should eq(false)
      tx4.invalid_tx.should eq(false)
    end

    it "should not be valid if a payment was send without any funds from exodus" do
      tx = FactoryGirl.create(:simple_send)
      tx.invalid_tx.should == true
    end

    it "should not be valid if a payment was send when the exodus payment was received later" do
      exodus = FactoryGirl.build(:exodus_transaction)
      tx = FactoryGirl.create(:simple_send)
      exodus.tx_date = tx.tx_date + 2.hours
      exodus.save
      
      tx.invalid_tx.should == true
    end

    it "should accept a payment after exodus transaction but ignore the one before exodus transaction" do
      exodus = FactoryGirl.build(:exodus_transaction)
      tx = FactoryGirl.create(:simple_send)
      exodus.tx_date = tx.tx_date + 2.hours
      exodus.save
      tx.invalid_tx.should == true

      tx2 = FactoryGirl.build(:simple_send)
      tx2.tx_date = exodus.tx_date + 1.hour
      tx2.save
      tx2.invalid_tx.should == false
    end
  end
end
